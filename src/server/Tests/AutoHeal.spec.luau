--!strict
-- Idle autoheal (S-226): 10 s without damage, then 1% of max health a
-- second up to full; any damage restarts the wait; unfinished structures
-- don't heal.
local AutoHeal = require("../Sim/AutoHeal")
local Combat = require("../Sim/Combat/Combat")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local function start(): Sim.Sim
	return Sim.new({
		seed = 7,
		players = { { id = 1, team = 1 }, { id = 2, team = 2 } },
		mapId = "skirmish:192",
		scenario = "standard_start", -- Commanders, so the match runs
		match = { mode = "FFA", win = "COMMAND_ENDS" },
	})
end

local function steps(sim: Sim.Sim, n: number)
	for _ = 1, n do
		Sim.step(sim)
	end
end

local SECOND = Sim.TICK_RATE

return function(t: RunAll.Context)
	t.test("a damaged unit heals 1% a second after 10 s without damage, up to full", function()
		local sim = start()
		local id = Spawn.unit(sim, "ord_paladin", 1, 500, 500, 0)
		local max = sim.defs.unitByIndex[sim.world.defIndex[id]].health
		Combat.queueDamage(sim.combat, id, max * 0.5, 0, 2)
		steps(sim, 1)
		local hurt = sim.world.health[id]
		t.expect(math.abs(hurt - max * 0.5) < 1e-6)
		steps(sim, 9 * SECOND)
		t.equal(sim.world.health[id], hurt, "no healing in the first 10 s")
		steps(sim, 3 * SECOND)
		t.expect(sim.world.health[id] > hurt, "healing after 10 s")
		t.expect(sim.world.health[id] <= hurt + max * 0.03 + 1e-6, "at most 1% a second")
		steps(sim, 60 * SECOND)
		t.equal(sim.world.health[id], max, "full, and never above")
	end)

	t.test("any damage restarts the wait", function()
		local sim = start()
		local id = Spawn.unit(sim, "ord_paladin", 1, 500, 500, 0)
		local max = sim.defs.unitByIndex[sim.world.defIndex[id]].health
		Combat.queueDamage(sim.combat, id, max * 0.5, 0, 2)
		steps(sim, 8 * SECOND)
		Combat.queueDamage(sim.combat, id, 1, 0, 1) -- a friendly hit counts too
		steps(sim, 1)
		local hurt = sim.world.health[id]
		steps(sim, 9 * SECOND)
		t.equal(sim.world.health[id], hurt, "the new hit restarted the 10 s")
		steps(sim, 3 * SECOND)
		t.expect(sim.world.health[id] > hurt)
	end)

	t.test("an unfinished structure doesn't heal", function()
		local sim = start()
		local id = Spawn.unit(sim, "ord_solar", 1, 500, 500, 0)
		World.setBuildProgress(sim.world, id, 0.5)
		World.setHealth(sim.world, id, 10)
		steps(sim, 20 * SECOND)
		t.equal(sim.world.health[id], 10)
		t.equal(AutoHeal.RATE, 0.01)
	end)
end
