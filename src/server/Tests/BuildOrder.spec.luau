--!strict
local Replay = require("../Sim/Replay")
local Sim = require("../Sim/Sim")
local BuildOrder = require("./Support/BuildOrder")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }
local LIMIT = 15 * 60 * 8 -- eight minutes of game time

local function newSim(): Sim.Sim
	return Sim.new({ seed = 7, players = PLAYERS, mapId = "start:96", scenario = "standard_start" })
end

return function(t: RunAll.Context)
	t.test("a scripted T1 build order reaches a factory producing tanks", function()
		local sim = newSim()
		local minStored = math.huge
		local driver = BuildOrder.new(sim)
		while sim.tick < LIMIT do
			BuildOrder.tick(driver)
			for _, team in sim.eco.teams do
				local acc = sim.eco.accounts[team]
				minStored = math.min(minStored, acc.supply.stored, acc.power.stored)
			end
			if driver.players[1].produced >= 3 and driver.players[2].produced >= 3 then
				break
			end
		end
		for _, playerId in sim.playerOrder do
			local p = driver.players[playerId]
			t.equal(p.next, #p.steps + 1, `player {playerId} worked through the build order`)
			t.expect(p.factory ~= 0, `player {playerId} finished a factory`)
			t.expect(p.produced >= 3, `player {playerId} produced {p.produced} tanks`)
		end
		for _, e in driver.timeline do
			t.expect(not string.find(e.what, "FAILED", 1, true), `step failed: {e.what}`)
		end
		t.expect(minStored >= 0, "stored never went negative")
		-- every produced tank is an army unit of the right faction
		local w = sim.world
		local tanks = { 0, 0 }
		for _, id in w.ids do
			local d = sim.defs.unitByIndex[w.defIndex[id]]
			if d.id == "ord_lancer" then
				tanks[w.owner[id]] += 1
			elseif d.id == "chs_ravager" then
				tanks[w.owner[id]] += 1
			end
		end
		t.deepEqual(tanks, { 3, 3 })
	end)

	t.test("the build order is deterministic across runs and replays", function()
		local a = BuildOrder.run(newSim(), 3, LIMIT)
		local b = BuildOrder.run(newSim(), 3, LIMIT)
		t.deepEqual(a.timeline, b.timeline, "same events at the same ticks")
		t.equal(Sim.hash(a.sim), Sim.hash(b.sim))
		local replayed, mismatch = Sim.runReplay(Replay.parse(Replay.serialize(a.sim.replay)), a.sim.tick)
		t.equal(mismatch, nil)
		t.equal(Sim.hash(replayed), Sim.hash(a.sim))
	end)
end
