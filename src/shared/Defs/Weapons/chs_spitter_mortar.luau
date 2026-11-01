--!strict
-- Spitter's mortar (S-233, batch 2; BAR's cormort).
return {
	id = "chs_spitter_mortar",
	type = "BALLISTIC",
	range = 300,
	reload = 2,
	projectileSpeed = 200,
	gravity = 60,
	highArc = true,
	accuracy = 2,
	damage = { LIGHT = 120, ARMORED = 110, STRUCTURE = 96, SHIP = 100, AIR = 0, SUB = 0 },
	aoe = 4,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "GROUND" },
	turret = { yawRate = 60, pitchRate = 40, tolerance = 2, minPitch = 20, maxPitch = 85, arc = 360 },
	fx = { muzzle = "flash_large", trail = "smoke_small", impact = "explosion_medium", sound = "mortar" },
}
