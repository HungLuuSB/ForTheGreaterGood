--!strict
-- Smart Reclaim (F42, S-183): a zone dragged in reclaim mode becomes one
-- AREA command; the Mason clears every wreck in it, one after another, and
-- the order line keeps the zone until the server reports the Mason idle.

local Api = require("../../src/client/Api")
local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local Combat = require("../../src/server/Sim/Combat/Combat")
local Schema = require("@shared/Net/Schema")

return function(t: any)
	t.test("a reclaim zone: one AREA order, every wreck in it reclaimed", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "start:64", scenario = "empty" })
		local victims = { Spawn.unit(sim, "chs_ravager", 2, 40, 0, 0), Spawn.unit(sim, "chs_ravager", 2, 60, 30, 0) }
		local mason = Spawn.unit(sim, "ord_mason", 1, -20, 10, 0)
		local world = World.new(sim.defs)
		local sent: { buffer } = {}
		local api = Api.new(world, function(p: buffer)
			table.insert(sent, p)
			assert(Sim.submit(sim, 1, p))
		end)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		local tick = 0
		local function step(n: number)
			for _ = 1, n do
				tick += 1
				Sim.step(sim)
				NetIn.applyOutbox(world, sim.net.players[1].outbox, tick / 15)
				Api.frame(api, tick / 15)
			end
		end
		step(3)
		for _, v in victims do
			sim.world.health[v] = 1
			Combat.queueDamage(sim.combat, v, 100, 0) -- leaves a wreck
		end
		step(4)
		local wrecks = 0
		for _ in world.wrecks do
			wrecks += 1
		end
		t.equal(wrecks, 2, "two wrecks known")
		api.actions.select({ mason })
		local ok, why = api.actions.areaOrder("reclaim", 50, 15, 60)
		t.expect(ok, `the order went out: {why}`)
		t.equal(#sent, 1, "one AREA command")
		local list = api.waypoints.byUnit[mason]
		t.expect(list ~= nil and list[1].kind == Schema.CmdType.AREA and list[1].radius == 60, "the order line holds the zone")
		api.actions.select({})
		t.expect(not api.actions.areaOrder("reclaim", 0, 0, 10), "nothing selected: nothing sent")
		t.equal(#sent, 1)
		for _ = 1, 15 * 90 do
			step(1)
			if next(world.wrecks) == nil then
				break
			end
		end
		t.equal(next(world.wrecks), nil, "both wrecks reclaimed")
		step(30)
		t.equal(api.waypoints.byUnit[mason], nil, "the zone ends when the Mason is idle")
	end)
end
