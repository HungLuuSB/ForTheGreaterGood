--!strict
-- Fatboy's heavy plasma cannon: a big, slow blast (S-181, the playtest's new units).
return {
	id = "ord_fatboy_cannon",
	type = "BALLISTIC",
	range = 255, -- -15% (S-203, the user's H43; was 300)
	reload = 6,
	projectileSpeed = 150,
	gravity = 60,
	accuracy = 2,
	damage = { LIGHT = 720, ARMORED = 640, STRUCTURE = 880, SHIP = 680, AIR = 0, SUB = 0 }, -- -20% (S-203, the user's H42)
	aoe = 48,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "ARMORED", "GROUND" },
	turret = { yawRate = 60, pitchRate = 30, tolerance = 2, minPitch = 0, maxPitch = 60, arc = 360 },
	fx = { muzzle = "flash_large", impact = "explosion_huge", sound = "plasma_heavy" }, -- a shell like the tanks' (S-193, G10); the big blast stays
}
