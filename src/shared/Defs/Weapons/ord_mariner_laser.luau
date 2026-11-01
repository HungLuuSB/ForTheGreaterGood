--!strict
-- Mariner's laser (S-233, batch 2; BAR's armamph).
return {
	id = "ord_mariner_laser",
	type = "HITSCAN",
	range = 97,
	reload = 0.9,
	damage = { LIGHT = 89, ARMORED = 80, STRUCTURE = 71, SHIP = 76, AIR = 0, SUB = 0 },
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "LIGHT", "GROUND", "STRUCTURE" },
	turret = { yawRate = 180, pitchRate = 90, tolerance = 3, minPitch = -15, maxPitch = 30, arc = 360 },
	fx = { muzzle = "flash_small", impact = "laser_hit", sound = "laser" },
}
