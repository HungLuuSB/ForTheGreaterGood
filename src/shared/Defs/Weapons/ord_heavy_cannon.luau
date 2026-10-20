--!strict
-- Main battle tank / heavy turret gun.
return {
	id = "ord_heavy_cannon",
	type = "BALLISTIC",
	range = 231,
	reload = 2.4,
	projectileSpeed = 420,
	gravity = 60,
	accuracy = 0.6,
	damage = { LIGHT = 270, ARMORED = 252, STRUCTURE = 216, SHIP = 198, AIR = 0, SUB = 0 },
	aoe = 5,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 70, pitchRate = 40, tolerance = 3, minPitch = -10, maxPitch = 20, arc = 360 },
	fx = { muzzle = "flash_large", impact = "explosion_medium", sound = "cannon_heavy" },
}
