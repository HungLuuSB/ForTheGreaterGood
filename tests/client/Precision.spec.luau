--!strict
-- The team's radar precision on the client (S-59, C-72): its finished
-- Pinpointers counted as the server counts them; unfinished ones don't
-- count, an enemy's don't either.

local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local Precision = require("../../src/client/Core/Precision")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sensors = require("../../src/server/Sim/Sensors")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")

return function(t: any)
	t.test("own finished Pinpointers give the server's precision", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:64", scenario = "empty" })
		for i = 0, 2 do
			Spawn.unit(sim, "ord_witness", 1, -200 + i * 40, -100, 0)
		end
		local frame = Spawn.unit(sim, "ord_witness", 1, -200, 100, 0)
		sim.world.buildProgress[frame] = 0.5 -- unfinished: doesn't count
		Spawn.unit(sim, "chs_augur", 2, 200, 0, 0) -- the enemy's
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		for tick = 1, 6 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick / 15)
		end
		local p, n = Precision.of(world)
		t.equal(n, 3)
		t.equal(p, Sensors.precision(sim.sensors, sim.players[1].allyTeam))
		t.equal(p, 0.5)
		t.expect(Precision.relevant(sim.defs.units.ord_witness), "a Pinpointer shows it")
		t.expect(Precision.relevant(sim.defs.units.ord_beacon), "a radar shows it")
		t.expect(not Precision.relevant(sim.defs.units.ord_lancer), "a tank doesn't")
	end)
end
