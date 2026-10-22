--!strict
-- Main battle tank / heavy turret gun.
return {
	id = "ord_heavy_cannon",
	type = "BALLISTIC",
	range = 240, -- faction pass (S-62)
	reload = 2.45, -- faction pass, tuned (S-62)
	projectileSpeed = 420,
	gravity = 60,
	accuracy = 0.6,
	damage = { LIGHT = 341, ARMORED = 319, STRUCTURE = 273, SHIP = 251, AIR = 0, SUB = 0 }, -- +10% (S-112: T2 tanks back in band after S-104)
	aoe = 5,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 70, pitchRate = 40, tolerance = 3, minPitch = -10, maxPitch = 20, arc = 360 },
	fx = { muzzle = "flash_large", impact = "explosion_medium", sound = "cannon_heavy" },
}
