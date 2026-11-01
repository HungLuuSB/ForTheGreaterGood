--!strict
-- Colossus's toplaser (S-233, batch 2; BAR's corjugg).
return {
	id = "chs_colossus_toplaser",
	type = "HITSCAN",
	range = 190,
	reload = 0.6,
	damage = { LIGHT = 170, ARMORED = 150, STRUCTURE = 140, SHIP = 140, AIR = 0, SUB = 0 },
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 180, pitchRate = 90, tolerance = 3, minPitch = -15, maxPitch = 30, arc = 360 },
	fx = { muzzle = "flash_small", impact = "laser_hit", sound = "laser" },
}
