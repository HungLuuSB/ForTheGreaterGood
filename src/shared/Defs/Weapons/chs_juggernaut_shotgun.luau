--!strict
-- Juggernaut's double-barrelled shotgun cannons (S-209, H40): a wide spray of slugs up close.
return {
	id = "chs_juggernaut_shotgun",
	type = "BALLISTIC",
	range = 150,
	reload = 1.6,
	salvo = { count = 6, delay = 0 },
	projectileSpeed = 420,
	gravity = 20,
	accuracy = 4,
	damage = { LIGHT = 120, ARMORED = 95, STRUCTURE = 80, SHIP = 80, AIR = 0, SUB = 0 },
	aoe = 6,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "LIGHT", "GROUND", "STRUCTURE" },
	turret = { yawRate = 120, pitchRate = 90, tolerance = 5, minPitch = -30, maxPitch = 30, arc = 360 },
	fx = { muzzle = "flash_large", impact = "explosion_small", sound = "cannon_heavy" },
}
