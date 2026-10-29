--!strict
-- Tzar's plasma cannon (S-181, the playtest's new units).
return {
	id = "chs_tzar_cannon",
	type = "BALLISTIC",
	range = 230, -- -15% (S-203, the user's H43; was 270)
	reload = 4.5,
	projectileSpeed = 150,
	gravity = 60,
	accuracy = 2,
	damage = { LIGHT = 880, ARMORED = 784, STRUCTURE = 1040, SHIP = 800, AIR = 0, SUB = 0 }, -- -20% (S-203, the user's H42)
	aoe = 40,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "ARMORED", "GROUND" },
	turret = { yawRate = 50, pitchRate = 30, tolerance = 2, minPitch = 0, maxPitch = 60, arc = 360 },
	fx = { muzzle = "flash_large", impact = "explosion_huge", sound = "plasma_heavy" }, -- a shell like the tanks' (S-193, G10); the big blast stays
}
