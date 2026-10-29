--!strict
-- Own units off camera stay live (C-205, OWN_STATUS, protocol 34, S-158):
-- a factory's queue and progress and a unit's health change while the
-- camera is elsewhere; a status that comes before the unit's strategic
-- record waits for it; ENTER takes over. Through the real NetOut → NetIn
-- path, plus the queue rebuilt from head and count.

local Api = require("../../src/client/Api")
local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local SimWorld = require("../../src/server/Sim/World")
local Spawn = require("../../src/server/Sim/Spawn")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15

return function(t: any)
	t.test("the queue an OWN_STATUS describes", function()
		t.equal(#World.statusQueue({ 5, 6, 7 }, 0, 0), 0, "empty")
		t.equal(table.concat(World.statusQueue({ 5, 6, 7 }, 6, 2), ","), "6,7", "the head moved on: the old tail")
		t.equal(table.concat(World.statusQueue({ 5, 6 }, 5, 4), ","), "5,6,6,6", "longer: padded with the last item")
		t.equal(table.concat(World.statusQueue(nil, 9, 3), ","), "9,9,9", "nothing known: the head repeated")
		t.equal(table.concat(World.statusQueue({ 5, 6, 7 }, 7, 1), ","), "7")
	end)

	t.test("a factory off camera: queue, progress and health stay live", function()
		local sim = Sim.new({ seed = 5, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "start:64", scenario = "empty" })
		local world = World.new(sim.defs)
		local api = Api.new(world, function(p: buffer)
			assert(Sim.submit(sim, 1, p))
		end)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		local plant = Spawn.unit(sim, "ord_vehplant", 1, -150, -150, 0)
		Spawn.unit(sim, "ord_fusion", 1, -150, 100, 0) -- power for production
		local px, pz = g:cellAt(sim.world.posX[plant], sim.world.posZ[plant])
		assert(Sim.submit(sim, 1, Commands.camera(px - 4, pz - 4, px + 4, pz + 4)))
		local tick = 0
		local function step(n: number)
			for _ = 1, n do
				tick += 1
				Sim.step(sim)
				NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
				Api.frame(api, tick * DT)
				table.clear(world.died)
				table.clear(world.entered)
				table.clear(world.left)
			end
		end
		step(5)
		api.actions.select({ plant })
		t.expect(api.actions.queueBuild("ord_lancer", 3), "queued")
		step(10)
		local u = assert(world.units[plant])
		t.equal(u.tier, "tactical")
		t.equal(#(u.queue or {}), 3)
		-- the camera far away
		assert(Sim.submit(sim, 1, Commands.camera(g.cellsX - 6, g.cellsZ - 6, g.cellsX - 1, g.cellsZ - 1)))
		step(15)
		u = assert(world.units[plant])
		t.equal(u.tier, "strategic", "off camera")
		local before = u.queueProgress or 0
		step(15 * 6)
		u = assert(world.units[plant])
		t.expect((u.queueProgress or 0) > before or #(u.queue or {}) < 3, `progress moves off camera ({before} → {u.queueProgress})`)
		t.expect(api.state.factoryQueues[plant] ~= nil, "the factory's queue still reaches the UI")
		-- finish one: the count drops and the head stays a Lancer
		local lancer = sim.defs.units.ord_lancer.index
		for _ = 1, 15 * 60 do
			step(1)
			if #(world.units[plant].queue or {}) < 3 then
				break
			end
		end
		u = world.units[plant]
		t.equal(#(u.queue or {}), 2, "one built, two left")
		t.equal((u.queue :: { number })[1], lancer)
		-- damage off camera shows
		SimWorld.setHealth(sim.world, plant, sim.world.health[plant] * 0.5)
		step(3)
		t.expect(math.abs((world.units[plant].health or 0) - 0.5) < 0.02, `health off camera ({world.units[plant].health})`)
		t.expect(world.ownStatus[plant] ~= nil, "kept while off camera")
		-- back on camera: ENTER takes over
		assert(Sim.submit(sim, 1, Commands.camera(px - 4, pz - 4, px + 4, pz + 4)))
		step(10)
		t.equal(world.units[plant].tier, "tactical")
		t.equal(world.ownStatus[plant], nil, "dropped on ENTER")
	end)

	t.test("a status before the unit's strategic record waits for it", function()
		local sim = Sim.new({ seed = 5, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "start:64", scenario = "empty" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		Sim.step(sim)
		NetIn.applyOutbox(world, sim.net.players[1].outbox, 0) -- the WELCOME
		t.equal(world.me.team, 1)
		local function header(wireTick: number): (any) -> ()
			return function(w: any)
				Schema.encodeTickHeader(w, wireTick)
			end
		end
		local function strategicHeader(wireTick: number): (any) -> ()
			return function(w: any)
				Schema.encodeStrategicHeader(w, wireTick) -- part 0 of 1 (S-212)
			end
		end
		local lancer = sim.defs.units.ord_lancer.index
		local plant = sim.defs.units.ord_vehplant.index
		-- OWN_STATUS for unit 77, which the client hasn't heard of yet
		local ev = Packer.chunk({ { kind = Schema.EventKind.OWN_STATUS, unitId = 77, health = 128, build = 255, queueHead = lancer, queueProgress = 64, queueCount = 2 } }, Schema.encodeEvent, nil, header(10))
		t.expect(NetIn.apply(world, "Events", ev[1], 0), "decoded")
		t.equal(world.units[77], nil, "no unit yet")
		t.expect(world.ownStatus[77] ~= nil, "kept by ID")
		-- its strategic record arrives: the status applies
		local st = Packer.chunk({ { unitId = 77, cell = 100, icon = plant, team = 1, flags = 0 } }, Schema.encodeStrategic, nil, strategicHeader(11))
		t.expect(NetIn.apply(world, "Strategic", st[1], 0), "decoded")
		local u = assert(world.units[77])
		t.expect(math.abs((u.health or 0) - 128 / 255) < 1e-6, "its health")
		t.equal(table.concat(u.queue or {}, ","), `{lancer},{lancer}`, "its queue")
		t.expect(math.abs((u.queueProgress or 0) - 64 / 255) < 1e-6, "the head's progress")
		-- a later snapshot keeps it (the record carries no health)
		st = Packer.chunk({ { unitId = 77, cell = 100, icon = plant, team = 1, flags = 0 } }, Schema.encodeStrategic, nil, strategicHeader(12))
		NetIn.apply(world, "Strategic", st[1], 0)
		t.expect(math.abs((world.units[77].health or 0) - 128 / 255) < 1e-6, "still after the next snapshot")
		-- death drops it
		ev = Packer.chunk({ { kind = Schema.EventKind.DEATH, unitId = 77, severity = 0, wreckId = 0 } }, Schema.encodeEvent, nil, header(13))
		NetIn.apply(world, "Events", ev[1], 0)
		t.equal(world.ownStatus[77], nil, "dropped with the unit")
	end)
end
