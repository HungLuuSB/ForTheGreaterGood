--!strict
-- Marksman's rifle (S-233, batch 2; BAR's armsnipe).
return {
	id = "ord_marksman_rifle",
	type = "HITSCAN",
	range = 320,
	reload = 13,
	damage = { LIGHT = 2800, ARMORED = 2500, STRUCTURE = 2200, SHIP = 2400, AIR = 0, SUB = 0 },
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "LIGHT", "GROUND" },
	turret = { yawRate = 90, pitchRate = 60, tolerance = 3, minPitch = -10, maxPitch = 30, arc = 360 },
	fx = { muzzle = "flash_medium", impact = "spark", sound = "cannon_heavy", color = { r = 255, g = 230, b = 120 } },
}
