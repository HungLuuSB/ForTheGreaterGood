--!strict
-- Fatboy's heavy plasma cannon: a big, slow blast (S-181, the playtest's new units).
return {
	id = "ord_fatboy_cannon",
	type = "BALLISTIC",
	range = 300,
	reload = 6,
	projectileSpeed = 150,
	gravity = 60,
	accuracy = 2,
	damage = { LIGHT = 900, ARMORED = 800, STRUCTURE = 1100, SHIP = 850, AIR = 0, SUB = 0 },
	aoe = 48,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "ARMORED", "GROUND" },
	turret = { yawRate = 60, pitchRate = 30, tolerance = 2, minPitch = 0, maxPitch = 60, arc = 360 },
	fx = { muzzle = "flash_large", impact = "explosion_huge", sound = "plasma_heavy" }, -- a shell like the tanks' (S-193, G10); the big blast stays
}
