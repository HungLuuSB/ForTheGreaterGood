--!strict
-- Citadel's gun (S-75): the longest, heaviest direct-fire gun.
return {
	id = "ord_citadel_gun",
	type = "BALLISTIC",
	range = 320,
	reload = 3.5,
	salvo = { count = 1, delay = 0 },
	projectileSpeed = 480,
	gravity = 60,
	accuracy = 0.3,
	damage = { LIGHT = 650, ARMORED = 600, STRUCTURE = 500, SHIP = 500, AIR = 0, SUB = 0 },
	aoe = 8,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 40, pitchRate = 30, tolerance = 2, minPitch = -10, maxPitch = 20, arc = 360 },
	fx = { muzzle = "flash_large", impact = "explosion_large", sound = "cannon_heavy" },
}
