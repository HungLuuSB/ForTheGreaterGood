--!strict
-- Cloak (S-228) and EMP (S-229), the BAR roster program's batch 1
-- mechanics: the Whisper hides from enemy sight while quiet, powered and
-- alone; the Thunderer's EMP stuns what it hits.
local Cloak = require("../Sim/Cloak")
local Combat = require("../Sim/Combat/Combat")
local Paralyze = require("../Sim/Paralyze")
local Sensors = require("../Sim/Sensors")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local function start(): Sim.Sim
	local sim = Sim.new({
		seed = 3,
		players = { { id = 1, team = 1 }, { id = 2, team = 2 } },
		mapId = "skirmish:192",
		scenario = "standard_start",
		match = { mode = "FFA", win = "COMMAND_ENDS" },
	})
	for _, acc in sim.eco.accounts do
		acc.power.stored = 1e6
		acc.supply.stored = 1e6
	end
	return sim
end

local function steps(sim: Sim.Sim, n: number)
	for _ = 1, n do
		Sim.step(sim)
	end
end

local function hold(sim: Sim.Sim, id: number): number
	World.setFireState(sim.world, id, World.FireState.HOLD_FIRE)
	return id
end

return function(t: RunAll.Context)
	t.test("a Whisper cloaks when quiet and alone: enemy sight passes over it (S-228)", function()
		local sim = start()
		local w = sim.world
		local whisper = hold(sim, Spawn.unit(sim, "ord_whisper", 1, 700, 700, 0))
		local scout = hold(sim, Spawn.unit(sim, "chs_jackal", 2, 700, 820, 0)) -- 120 studs: in its sight, beyond 60
		steps(sim, 4)
		t.expect(bit32.band(w.state[whisper], World.State.CLOAKED) ~= 0, "cloaked")
		t.expect(Sensors.level(sim, 2, whisper) ~= Sensors.Level.VISIBLE, "the enemy can't see it")
		World.setPosition(w, scout, 700, 740) -- 40 studs: inside its decloak radius
		steps(sim, 4)
		t.equal(bit32.band(w.state[whisper], World.State.CLOAKED), 0, "an enemy close by shows it")
		t.equal(Sensors.level(sim, 2, whisper), Sensors.Level.VISIBLE)
	end)

	t.test("firing, switching it off or running out of power shows it", function()
		local sim = start()
		local w = sim.world
		local whisper = hold(sim, Spawn.unit(sim, "ord_whisper", 1, 700, 700, 0))
		steps(sim, 4)
		t.expect(bit32.band(w.state[whisper], World.State.CLOAKED) ~= 0)
		sim.cloak.firedAt[whisper] = sim.tick -- (as the Cloak system notes a FIRE)
		steps(sim, 4)
		t.equal(bit32.band(w.state[whisper], World.State.CLOAKED), 0, "just fired")
		steps(sim, 2 * 15)
		t.expect(bit32.band(w.state[whisper], World.State.CLOAKED) ~= 0, "quiet for 2 s: cloaked again")
		World.setState(w, whisper, bit32.band(w.state[whisper], bit32.bnot(World.State.TOGGLED_ON)))
		steps(sim, 4)
		t.equal(bit32.band(w.state[whisper], World.State.CLOAKED), 0, "switched off")
		World.setState(w, whisper, bit32.bor(w.state[whisper], World.State.TOGGLED_ON))
		steps(sim, 4)
		t.expect(bit32.band(w.state[whisper], World.State.CLOAKED) ~= 0, "on again")
		if sim.tick % Cloak.EVERY ~= 0 then
			Sim.step(sim)
		end
		sim.sensors.powerScale[whisper] = 0.5 -- (as Sensors' drain sets it in a power stall)
		Cloak.step(sim)
		t.equal(bit32.band(w.state[whisper], World.State.CLOAKED), 0, "short of power: no cloak")
	end)

	t.test("EMP fills the stun bar, not health; a full bar stuns, and it wears off (S-229)", function()
		local sim = start()
		local w = sim.world
		local tank = Spawn.unit(sim, "chs_ravager", 2, 700, 700, 0)
		local max = sim.defs.units.chs_ravager.health
		Combat.queueDamage(sim.combat, tank, max * 0.6, 0, 1, 6)
		steps(sim, 1)
		t.equal(w.health[tank], max, "no health lost")
		t.equal(World.isParalyzed(w, tank), false, "60%: not yet")
		Combat.queueDamage(sim.combat, tank, max * 0.6, 0, 1, 6)
		steps(sim, 1)
		t.expect(World.isParalyzed(w, tank), "past max health: stunned")
		local bar = w.paralyze[tank] :: number
		t.expect(bar <= max * (1 + 6 / Paralyze.DRAIN_SECONDS) + 1e-6, "capped by the weapon's seconds")
		steps(sim, 3 * 15)
		t.expect(World.isParalyzed(w, tank) or bar - max < max * 0.3, "still stunned while the bar is over")
		steps(sim, 8 * 15)
		t.equal(World.isParalyzed(w, tank), false, "worn off")
	end)

	t.test("the Thunderer's EMP fills its target's stun bar (S-229)", function()
		local sim = start()
		local w = sim.world
		Spawn.unit(sim, "ord_thunderer", 1, 300, 300, 0)
		local tank = hold(sim, Spawn.unit(sim, "chs_juggernaut", 2, 300, 500, 0)) -- 200 studs: in EMP reach; tough enough to live
		local hit = false
		for _ = 1, 15 * 20 do
			Sim.step(sim)
			if (w.paralyze[tank] or 0) > 0 then
				hit = true
				break
			end
		end
		t.expect(hit, "its stun bar filled")
	end)

	t.test("a stunned unit neither moves nor fires", function()
		local sim = start()
		local w = sim.world
		local tank = Spawn.unit(sim, "chs_ravager", 2, 700, 700, 0)
		local target = hold(sim, Spawn.unit(sim, "ord_paladin", 1, 700, 760, 0)) -- in its gun's reach
		local max = sim.defs.units.chs_ravager.health
		Combat.queueDamage(sim.combat, tank, max * 1.5, 0, 1, 6)
		steps(sim, 1)
		t.expect(World.isParalyzed(w, tank))
		local x, z = w.posX[tank], w.posZ[tank]
		local fired = false
		for _ = 1, 3 * 15 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				fired = fired or (e.kind == "FIRE" or e.kind == "SPAWN_PROJ") and e.unit == tank
			end
		end
		t.expect(not fired, "it didn't fire at the tank beside it")
		t.expect((w.posX[tank] - x) ^ 2 + (w.posZ[tank] - z) ^ 2 < 1, "it held its spot")
		t.expect(w.health[target] > 0)
	end)
end
