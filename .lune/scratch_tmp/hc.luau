local Combat = require("../../src/server/Sim/Combat/Combat")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local World = require("../../src/server/Sim/World")
local function measure(gun, wname, dist, shots)
	local sim = Sim.new({ seed = 7, players = { { id = 1, team = 1 }, { id = 2, team = 3 } }, mapId = "flat:128" })
	local w, c = sim.world, sim.combat
	local g = Spawn.unit(sim, gun, 1, -dist / 2, 0, math.pi / 2)
	local sp = Spawn.unit(sim, "ord_watchtower", 1, dist / 2 - 40, 60, 0)
	local t = Spawn.unit(sim, "chs_ravager", 2, dist / 2, 0, -math.pi / 2)
	World.setFireState(w, t, World.FireState.HOLD_FIRE)
	World.setHealth(w, t, 1e9)
	local fired = 0
	for _ = 1, 15 * 120 do
		Sim.step(sim)
		for _, e in c.events do if e.kind == "SPAWN_PROJ" or e.kind == "FIRE" then fired += 1 end end
		if fired >= shots then break end
	end
	for _ = 1, 60 do Sim.step(sim) end
	local wd = sim.defs.weapons[wname]
	local dmg = (1e9 - w.health[t]) / fired / wd.damage.ARMORED
	local model = Combat.hitChance(wd, c.profiles[sim.defs.units.chs_ravager.index], dist)
	print(string.format("%-12s %4d studs: %d shots, damage per shot %.2f of full; model %.2f", gun, dist, fired, dmg, model))
end
measure("ord_verdict", "ord_howitzer", 200, 60)
measure("ord_verdict", "ord_howitzer", 350, 60)
measure("ord_verdict", "ord_howitzer", 440, 60)
measure("chs_hellmouth", "chs_mortar", 200, 60)
measure("chs_hellmouth", "chs_mortar", 350, 60)
measure("ord_lancer", "ord_light_cannon", 60, 60)
measure("ord_lancer", "ord_light_cannon", 180, 60)
measure("chs_ravager", "chs_light_cannon", 60, 60)
measure("chs_ravager", "chs_light_cannon", 170, 60)
