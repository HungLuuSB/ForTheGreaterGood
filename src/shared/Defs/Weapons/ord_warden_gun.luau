--!strict
-- Warden's gun (S-64): long, precise and heavy; fires only deployed.
return {
	id = "ord_warden_gun",
	type = "BALLISTIC",
	range = 280,
	reload = 3,
	salvo = { count = 1, delay = 0 },
	projectileSpeed = 440,
	gravity = 60,
	accuracy = 0.35,
	damage = { LIGHT = 380, ARMORED = 350, STRUCTURE = 300, SHIP = 280, AIR = 0, SUB = 0 },
	aoe = 5,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 60, pitchRate = 35, tolerance = 2, minPitch = -10, maxPitch = 20, arc = 360 },
	fx = { muzzle = "flash_large", impact = "explosion_medium", sound = "cannon_heavy" },
}
