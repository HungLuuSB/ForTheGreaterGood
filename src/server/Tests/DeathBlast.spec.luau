--!strict
-- The Fusion Reactor's death explosion (S-70, guide 8.5, audit item 11).
local Combat = require("../Sim/Combat/Combat")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

return function(t: RunAll.Context)
	t.test("a reactor that is destroyed blasts everything near it, its own side included", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local reactor = Spawn.unit(sim, "ord_fusion", 1, 0, 0)
		local ownTank = Spawn.unit(sim, "ord_lancer", 1, 40, 0)
		local enemyTank = Spawn.unit(sim, "chs_ravager", 2, -40, 0)
		local far = Spawn.unit(sim, "chs_ravager", 2, -300, 0)
		for _, id in { ownTank, enemyTank, far } do
			World.setFireState(w, id, World.FireState.HOLD_FIRE)
		end
		local hp = { [ownTank] = w.health[ownTank], [enemyTank] = w.health[enemyTank], [far] = w.health[far] }
		Combat.queueDamage(sim.combat, reactor, 1e6, 0)
		local blast = false
		for _ = 1, 3 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "BLAST" and e.unit == reactor then
					blast = true
				end
			end
		end
		t.expect(blast, "a BLAST event")
		t.expect(not World.isAlive(w, enemyTank), "the enemy tank 40 studs off is gone (2,500 at the center)")
		t.expect(not World.isAlive(w, ownTank), "so is its own")
		t.equal(w.health[far], hp[far], "a tank 300 studs off is untouched")
	end)

	t.test("every unit blasts on death, by its worth and power (S-178): a generator's hurts, a scout's barely; Commanders' are huge", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local gen = Spawn.unit(sim, "ord_solar", 1, 0, 0)
		local tank = Spawn.unit(sim, "chs_ravager", 2, -20, 0)
		World.setFireState(w, tank, World.FireState.HOLD_FIRE)
		local hp = w.health[tank]
		Combat.queueDamage(sim.combat, gen, 1e6, 0)
		for _ = 1, 3 do
			Sim.step(sim)
		end
		t.expect(not World.isAlive(w, gen), "the generator died")
		t.expect(w.health[tank] < hp and w.health[tank] > 0, `its blast hurt the tank next to it ({hp} → {w.health[tank]})`)
		local defs = sim.defs.units
		t.expect(defs.ord_solar.deathBlast.damage > 4 * defs.chs_jackal.deathBlast.damage, "a generator's blast is far bigger than a scout's")
		t.expect(defs.ord_sovereign.deathBlast.aoe < sim.defs.weapons.ord_nuke.aoe :: number, "a Commander's blast is smaller than a nuke's")
		t.expect(defs.ord_sovereign.deathBlast.damage >= 4000, "but huge")
	end)

	t.test("self-destructs and an upgraded extractor set off no blast", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local gen = Spawn.unit(sim, "ord_solar", 1, 0, 0)
		local tank = Spawn.unit(sim, "chs_ravager", 2, -20, 0)
		World.setFireState(w, tank, World.FireState.HOLD_FIRE)
		local hp = w.health[tank]
		sim.match.quiet[gen] = true
		Combat.queueDamage(sim.combat, gen, 1e6, 0)
		for _ = 1, 3 do
			Sim.step(sim)
		end
		t.expect(not World.isAlive(w, gen), "the generator self-destructed")
		t.equal(w.health[tank], hp, "quietly")
	end)
end
