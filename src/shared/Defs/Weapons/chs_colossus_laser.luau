--!strict
-- Colossus's twin lower lasers, as one weapon (S-233, batch 2; BAR's corjugg).
return {
	id = "chs_colossus_laser",
	type = "HITSCAN",
	range = 150,
	reload = 0.4,
	damage = { LIGHT = 166, ARMORED = 150, STRUCTURE = 130, SHIP = 140, AIR = 0, SUB = 0 },
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "LIGHT", "GROUND", "STRUCTURE" },
	turret = { yawRate = 300, pitchRate = 120, tolerance = 4, minPitch = -20, maxPitch = 30, arc = 360 },
	fx = { muzzle = "flash_small", impact = "laser_hit", sound = "laser" },
}
