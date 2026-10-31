--!strict
-- Fulgur's close lightning gun (S-230; BAR's armlatnk).
return {
	id = "ord_fulgur_lightning",
	type = "HITSCAN",
	range = 100,
	reload = 1,
	damage = { LIGHT = 140, ARMORED = 130, STRUCTURE = 104, SHIP = 110, AIR = 0, SUB = 0 },
	aoe = 4,
	edgeEffectiveness = 0.5,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "LIGHT", "GROUND", "STRUCTURE" },
	turret = { yawRate = 120, pitchRate = 80, tolerance = 4, minPitch = -10, maxPitch = 25, arc = 360 },
	fx = { muzzle = "flash_small", impact = "spark", sound = "laser" },
}
