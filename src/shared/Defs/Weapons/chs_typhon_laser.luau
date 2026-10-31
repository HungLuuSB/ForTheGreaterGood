--!strict
-- Typhon's twin heavy lasers (S-230; BAR's corsok).
return {
	id = "chs_typhon_laser",
	type = "HITSCAN",
	range = 150,
	reload = 1.5,
	damage = { LIGHT = 560, ARMORED = 600, STRUCTURE = 500, SHIP = 510, AIR = 0, SUB = 0 },
	aoe = 0,
	edgeEffectiveness = 0.5,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 120, pitchRate = 80, tolerance = 4, minPitch = -10, maxPitch = 25, arc = 360 },
	fx = { muzzle = "flash_medium", impact = "spark", sound = "laser" },
}
