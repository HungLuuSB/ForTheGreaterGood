--!strict
-- Stormcaller's lightning (S-233, batch 2; BAR's armzeus).
return {
	id = "ord_stormcaller_lightning",
	type = "HITSCAN",
	range = 99,
	reload = 2.2,
	damage = { LIGHT = 240, ARMORED = 220, STRUCTURE = 190, SHIP = 200, AIR = 0, SUB = 0 },
	aoe = 4,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "LIGHT", "ARMORED", "GROUND" },
	turret = { yawRate = 180, pitchRate = 90, tolerance = 3, minPitch = -15, maxPitch = 30, arc = 360 },
	fx = { muzzle = "flash_small", impact = "spark", sound = "laser", color = { r = 150, g = 200, b = 255 } },
}
