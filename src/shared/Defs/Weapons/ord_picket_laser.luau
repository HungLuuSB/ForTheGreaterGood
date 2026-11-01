--!strict
-- Picket's laser (S-233, batch 2; BAR's armwar).
return {
	id = "ord_picket_laser",
	type = "HITSCAN",
	range = 110,
	reload = 0.4,
	damage = { LIGHT = 61, ARMORED = 55, STRUCTURE = 49, SHIP = 52, AIR = 0, SUB = 0 },
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "LIGHT", "GROUND", "STRUCTURE" },
	turret = { yawRate = 300, pitchRate = 120, tolerance = 4, minPitch = -20, maxPitch = 30, arc = 360 },
	fx = { muzzle = "flash_small", impact = "laser_hit", sound = "laser", color = { r = 255, g = 60, b = 40 } },
}
