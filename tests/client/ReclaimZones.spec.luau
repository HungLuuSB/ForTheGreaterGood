--!strict
-- Wrecks with supply and resurrect progress (C-216, S-168): WRECK and
-- WRECK_STATE through the real NetOut → NetIn path; wreck bars; reclaim
-- zones grouping nearby wrecks with their total supply; the hover label;
-- workers-only selections.

local Bars = require("../../src/client/Core/Bars")
local NetIn = require("../../src/client/Core/NetIn")
local ReclaimZones = require("../../src/client/Core/ReclaimZones")
local World = require("../../src/client/Core/World")
local Commands = require("../../src/client/Core/Commands")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local Combat = require("../../src/server/Sim/Combat/Combat")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")

local CT = Schema.CmdType

local function command(cmdType: number, unit: number, target: number): buffer
	local w = Packer.Writer.new(64)
	Schema.encodeCommand(w, { cmdType = cmdType, flags = 0, unitIds = { unit }, targetId = target })
	return w:finish()
end

local function wreck(world: any, id: number, defIndex: number, x: number, z: number, supply: number, full: number, rez: number?)
	world.wrecks[id] = { id = id, defIndex = defIndex, x = x, z = z, heading = 0, supply = supply, fullSupply = full, rez = rez or 0 }
end

return function(t: any)
	t.test("wreck supply and resurrect progress arrive through the real path", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "start:64", scenario = "empty" })
		local victim = Spawn.unit(sim, "chs_ravager", 2, 40, 0, 0)
		local victim2 = Spawn.unit(sim, "chs_ravager", 2, 40, 40, 0)
		local mason = Spawn.unit(sim, "ord_mason", 1, -20, 0, 0) -- sees the victims' spots
		local mason2 = Spawn.unit(sim, "ord_mason", 1, -20, 40, 0)
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		local tick = 0
		local function step(n: number)
			for _ = 1, n do
				tick += 1
				Sim.step(sim)
				NetIn.applyOutbox(world, sim.net.players[1].outbox, tick / 15)
			end
		end
		step(3)
		for _, v in { victim, victim2 } do
			sim.world.health[v] = 1
			Combat.queueDamage(sim.combat, v, 100, 0) -- low overkill: leaves a wreck
		end
		step(4)
		local a, b = sim.combat.wreckIds[1], sim.combat.wreckIds[2]
		local w = assert(world.wrecks[a])
		t.expect(w.fullSupply > 0 and w.supply == w.fullSupply, `full at first ({w.supply} of {w.fullSupply})`)
		t.equal(w.rez, 0)
		-- reclaim one, resurrect the other: WRECK_STATE moves both
		assert(Sim.submit(sim, 1, command(CT.RECLAIM, mason, a)))
		assert(Sim.submit(sim, 1, command(CT.RESURRECT, mason2, b)))
		for _ = 1, 15 * 20 do
			step(1)
			local wa, wb = world.wrecks[a], world.wrecks[b]
			if wa and wa.supply < wa.fullSupply and wb and wb.rez > 0 then
				break
			end
		end
		local wa, wb = world.wrecks[a], world.wrecks[b]
		t.expect(wa ~= nil and wa.supply < wa.fullSupply, "reclaiming lowers the supply the client shows")
		t.expect(wb ~= nil and wb.rez > 0, "resurrecting raises the progress the client shows")
	end)

	t.test("bars: partly reclaimed (dark green) and being resurrected (purple)", function()
		local sim = Sim.new({ seed = 5, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "start:64", scenario = "empty" })
		local world = World.new(sim.defs)
		world.me = { player = 1, team = 1, allyTeam = 1 }
		local lancer = sim.defs.units.ord_lancer.index
		wreck(world, 1, lancer, 0, 0, 40, 40) -- untouched: no bar
		wreck(world, 2, lancer, 50, 0, 10, 40) -- a quarter left
		wreck(world, 3, lancer, 100, 0, 40, 40, 0.5) -- full, half resurrected
		wreck(world, 4, lancer, 150, 0, 20, 40, 0.25)
		local list = Bars.wreckList(world)
		t.equal(#list, 3, "only touched wrecks")
		t.expect(list[1].wreck and math.abs((list[1].supplyShare :: number) - 0.25) < 1e-9 and list[1].rez == nil, "supply only")
		t.expect(list[2].supplyShare == nil and list[2].rez == 0.5 and list[2].health == 0.5, "resurrect only")
		t.expect(list[3].supplyShare == 0.5 and list[3].rez == 0.25, "both")
		local d = Bars.draws(world, list, function(x: number, _y: number, z: number)
			return x + 200, z + 200, true
		end, 1000, 1000, 1, 0)
		t.equal(#d, 3, "drawn under each wreck")
	end)

	t.test("zones: nearby wrecks grouped, supply summed; hover; workers only", function()
		local sim = Sim.new({ seed = 5, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "start:64", scenario = "empty" })
		local world = World.new(sim.defs)
		world.me = { player = 1, team = 1, allyTeam = 1 }
		local lancer = sim.defs.units.ord_lancer.index
		wreck(world, 1, lancer, 0, 0, 30, 40)
		wreck(world, 2, lancer, 60, 0, 10, 40) -- 60 from the first: same zone
		wreck(world, 3, lancer, 400, 0, 25, 40) -- far: its own zone
		wreck(world, 4, lancer, 420, 0, 0, 40) -- empty: no zone
		local zones = ReclaimZones.of(world)
		t.equal(#zones, 2)
		t.equal(zones[1].supply, 40, "the bigger field first: 30 + 10")
		t.equal(zones[1].count, 2)
		t.expect(math.abs(zones[1].x - 15) < 1e-9, "centre weighted by supply")
		t.expect(zones[1].r >= 45 + ReclaimZones.PAD - 1e-9, "holds both wrecks")
		t.equal(zones[2].supply, 25)
		local w = ReclaimZones.wreckAt(world, 58, 5)
		t.equal(w and w.id, 2, "the wreck under the point")
		t.equal(ReclaimZones.wreckAt(world, 200, 200), nil)
		world.wrecks[2].rez = 0.4
		t.equal(ReclaimZones.label(world, world.wrecks[2]), "Lancer wreck · 10 supply · resurrect 40%")
		world.units[10] = { id = 10, tier = "tactical", team = 1, defIndex = sim.defs.units.ord_mason.index, x = 0, z = 0, alt = 0, state = 0 } :: any
		world.units[11] = { id = 11, tier = "tactical", team = 1, defIndex = lancer, x = 0, z = 0, alt = 0, state = 0 } :: any
		t.expect(ReclaimZones.workersOnly(world, { 10 }), "a Mason")
		t.expect(not ReclaimZones.workersOnly(world, { 10, 11 }), "with a Lancer: no")
		t.expect(not ReclaimZones.workersOnly(world, {}), "nothing selected: no")
	end)
end
