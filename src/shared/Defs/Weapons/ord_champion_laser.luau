--!strict
-- Champion's laser (S-233, batch 2; BAR's armraz).
return {
	id = "ord_champion_laser",
	type = "HITSCAN",
	range = 170,
	reload = 0.8,
	damage = { LIGHT = 720, ARMORED = 650, STRUCTURE = 580, SHIP = 610, AIR = 0, SUB = 0 },
	aoe = 3,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 300, pitchRate = 120, tolerance = 4, minPitch = -20, maxPitch = 30, arc = 360 },
	fx = { muzzle = "flash_small", impact = "laser_hit", sound = "laser", color = { r = 255, g = 60, b = 40 } },
}
