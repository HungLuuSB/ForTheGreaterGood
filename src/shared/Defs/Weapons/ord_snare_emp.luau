--!strict
-- Snare's emp (S-233, batch 2; BAR's armspid).
return {
	id = "ord_snare_emp",
	type = "HITSCAN",
	range = 99,
	reload = 2.2,
	paralyzer = true,
	damage = { LIGHT = 940, ARMORED = 940, STRUCTURE = 940, SHIP = 940, AIR = 0, SUB = 0 },
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 180, pitchRate = 90, tolerance = 3, minPitch = -15, maxPitch = 30, arc = 360 },
	fx = { muzzle = "flash_small", impact = "spark", sound = "laser", color = { r = 120, g = 160, b = 255 } },
}
