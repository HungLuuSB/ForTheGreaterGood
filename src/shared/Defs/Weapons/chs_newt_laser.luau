--!strict
-- Newt's laser (S-233, batch 2; BAR's coramph).
return {
	id = "chs_newt_laser",
	type = "HITSCAN",
	range = 110,
	reload = 1.4,
	damage = { LIGHT = 170, ARMORED = 150, STRUCTURE = 140, SHIP = 140, AIR = 0, SUB = 0 },
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "LIGHT", "GROUND", "STRUCTURE" },
	turret = { yawRate = 180, pitchRate = 90, tolerance = 3, minPitch = -15, maxPitch = 30, arc = 360 },
	fx = { muzzle = "flash_small", impact = "laser_hit", sound = "laser" },
}
