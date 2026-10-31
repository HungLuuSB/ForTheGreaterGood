--!strict
-- Wrecks wear down to scrap heaps (protocol 45, S-227; C-278): WRECK and
-- WRECK_STATE carry the heap flag, WRECK_HIT says a blast hit a wreck. The
-- client queues the heap swap and the sparks for the renderer, names a heap
-- in its tooltip with what's left to reclaim, and won't resurrect one.

local Api = require("../../src/client/Api")
local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local ReclaimZones = require("../../src/client/Core/ReclaimZones")
local World = require("../../src/client/Core/World")
local Combat = require("../../src/server/Sim/Combat/Combat")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15
local EK = Schema.EventKind

local function blast(damage: number, aoe: number): any
	return { aoe = aoe, edgeEffectiveness = 1, damage = { LIGHT = 0, ARMORED = 0, STRUCTURE = damage, SHIP = 0, AIR = 0, SUB = 0 } }
end

return function(t: any)
	t.test("WRECK and WRECK_STATE carry the heap flag, WRECK_HIT queues sparks; a heap reads as one and can't be resurrected", function()
		local sim = Sim.new({ seed = 5, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "start:64", scenario = "empty" })
		local world = World.new(sim.defs)
		local sent = {}
		local api = Api.new(world, function(p: buffer)
			table.insert(sent, p)
		end)
		NetOut.join(sim, 1)
		Sim.step(sim)
		NetIn.applyOutbox(world, sim.net.players[1].outbox, 0) -- the WELCOME
		local g = world.grid
		local function events(wireTick: number, list: { any })
			local msgs = Packer.chunk(list, Schema.encodeEvent, nil, function(w: any)
				Schema.encodeTickHeader(w, wireTick)
			end)
			for _, m in msgs do
				t.expect(NetIn.apply(world, "Events", m, 0), "decoded")
			end
		end
		local lancer = sim.defs.units.ord_lancer
		local cell, ox, oz = g:encode(40, 40)
		local cell2, ox2, oz2 = g:encode(-40, 40)
		events(10, {
			{ kind = EK.WRECK, wreckId = 5, defIndex = lancer.index, cell = cell, offX = ox, offZ = oz, heading = 0, supply = 60, fullSupply = 100, featureKind = 0, heap = false },
			{ kind = EK.WRECK, wreckId = 6, defIndex = lancer.index, cell = cell2, offX = ox2, offZ = oz2, heading = 0, supply = 30, fullSupply = 100, featureKind = 0, heap = true },
		})
		t.equal(world.wrecks[5].heap, nil, "a wreck")
		t.equal(world.wrecks[6].heap, true, "first seen as a heap")
		t.equal(#world.wreckHeaped, 0, "no swap for one first seen as a heap")
		events(11, { { kind = EK.WRECK_HIT, wreckId = 5 }, { kind = EK.WRECK_STATE, wreckId = 5, supply = 45, rez = 0, heap = false } })
		t.equal(world.wreckHits[1], 5, "sparks queued")
		t.equal(world.wrecks[5].supply, 45, "what's left to reclaim follows")
		t.equal(world.wrecks[5].heap, nil)
		events(12, { { kind = EK.WRECK_STATE, wreckId = 5, supply = 38, rez = 0, heap = true } })
		t.equal(world.wrecks[5].heap, true, "worn to a heap")
		t.equal(world.wreckHeaped[1], 5, "the swap queued once")
		events(13, { { kind = EK.WRECK_STATE, wreckId = 5, supply = 30, rez = 0, heap = true } })
		t.equal(#world.wreckHeaped, 1, "not queued again")
		t.equal(ReclaimZones.label(world, world.wrecks[5]), `{lancer.name} scrap heap · 30 supply`)
		-- a worker can reclaim the heap but not resurrect it
		local worker: string? = nil
		for id, def in sim.defs.units do
			if def.canResurrect and string.sub(id, 1, 4) == "ord_" then
				worker = id
				break
			end
		end
		assert(worker, "a worker that resurrects")
		world.units[900] = { id = 900, defIndex = sim.defs.units[worker].index, team = world.me.team, tier = "tactical", x = 0, z = 0, alt = 0, heading = 0, snaps = {}, lastTick = 0, state = 0, weapon = 0, aim = {} } :: any
		api.actions.select({ 900 })
		t.expect(api.actions.setCommandMode("resurrect"))
		local ok, why = api.actions.commandAt(40, 40, nil, false, false)
		t.expect(not ok, "no resurrect on a heap")
		t.equal(why, "a scrap heap can't be resurrected")
		t.expect(api.actions.setCommandMode("reclaim"))
		t.expect((api.actions.commandAt(40, 40, nil, false, false)), "reclaim works")
		World.welcome(world, { mapId = world.mapId, player = 1, team = 1, allyTeam = 1 } :: any, 0)
		t.equal(#world.wreckHeaped + #world.wreckHits, 0, "a join clears the queues")
	end)

	-- (WRECK_HIT itself is a combat event of the tick it happens in: a blast
	-- set off between steps is cleared before NetOut sends it, so its bytes
	-- are checked above; Wrecks.spec checks the server raises it.)
	t.test("from the server: a blast on a wreck in sight wears down what it holds, and below 40% it's a heap", function()
		local sim = Sim.new({ seed = 4, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:64", scenario = "empty" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		Spawn.unit(sim, "ord_lancer", 1, 0, 0, 0) -- eyes on the wreck
		local d = sim.defs.units.ord_lancer
		local wid = Combat.addWreck(sim.combat, 30, 0, d, 0)
		local tick = 0
		local function step(n: number)
			for _ = 1, n do
				tick += 1
				Sim.step(sim)
				NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			end
		end
		step(4)
		local w = world.wrecks[wid]
		t.expect(w ~= nil, "the client has the wreck")
		t.equal(w.heap, nil)
		local hp = d.health * Combat.WRECK_HEALTH
		Combat.explode(sim.combat, sim.world, 30, 0, 0, blast(hp * 0.3, 20), 0, 0, 0)
		step(2)
		t.expect(world.wrecks[wid].supply < w.fullSupply, `its supply went down ({world.wrecks[wid].supply} / {w.fullSupply})`)
		t.equal(world.wrecks[wid].heap, nil, "70%: still a wreck")
		Combat.explode(sim.combat, sim.world, 30, 0, 0, blast(hp * 0.4, 20), 0, 0, 0)
		step(2)
		t.equal(world.wrecks[wid].heap, true, "30%: a scrap heap")
		t.expect(table.find(world.wreckHeaped, wid) ~= nil, "the swap queued")
	end)
end
