--!strict
-- Sharing with allies (F23, S-176): the team panel's commands go through
-- the real Sim, and the SHARE events come back to the ally team as lines.

local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local Share = require("../../src/client/Core/Share")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")

local DT = 1 / 15

local function names(pid: number): string
	return ({ "Ann", "Bo", "Cy" })[pid] or `Player {pid}`
end

return function(t: any)
	t.test("give supply and units to an ally, ask for power: the events reach the ally team", function()
		local sim = Sim.new({
			seed = 4,
			players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 2, allyTeam = 1 }, { id = 3, team = 3, allyTeam = 2 } },
			mapId = "flat:64",
			scenario = "empty",
		})
		local tank = Spawn.unit(sim, "ord_lancer", 1, 0, 0, 0)
		local ally, enemy = World.new(sim.defs), World.new(sim.defs)
		NetOut.join(sim, 2)
		NetOut.join(sim, 3)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 2, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		local function step(n: number)
			for _ = 1, n do
				Sim.step(sim)
				NetIn.applyOutbox(ally, sim.net.players[2].outbox, sim.tick * DT)
				NetIn.applyOutbox(enemy, sim.net.players[3].outbox, sim.tick * DT)
			end
		end
		step(6)
		assert(Sim.submit(sim, 1, Share.resource(2, "supply", 100)))
		assert(Sim.submit(sim, 1, Share.units({ tank }, 2)))
		assert(Sim.submit(sim, 1, Share.ask("power")))
		step(6)
		local lines = {}
		for _, e in ally.shares do
			table.insert(lines, Share.text(e, 2, names))
		end
		print("    ally sees: " .. table.concat(lines, " | "))
		t.expect(table.find(lines, "Ann gave you 100 supply") ~= nil, "the supply gift")
		t.expect(table.find(lines, "Ann gave you 1 unit") ~= nil, "the unit gift")
		t.expect(table.find(lines, "Ann asks for power") ~= nil, "the request")
		t.equal(#enemy.shares, 0, "the enemy hears nothing")
		local mine = 0
		for _, u in ally.units do
			if u.team == 2 then
				mine += 1
			end
		end
		t.equal(mine, 1, "the Lancer is the ally's now")
		t.expect(ally.teamEco[2] ~= nil, "the own Eco record kept by team")
	end)
end
