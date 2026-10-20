--!strict
-- Main battle tank / heavy turret gun.
return {
	id = "chs_heavy_cannon",
	type = "BALLISTIC",
	range = 210,
	reload = 2.4,
	projectileSpeed = 420,
	gravity = 60,
	accuracy = 0.6,
	damage = { LIGHT = 330, ARMORED = 308, STRUCTURE = 264, SHIP = 242, AIR = 0, SUB = 0 },
	aoe = 5,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 70, pitchRate = 40, tolerance = 3, minPitch = -10, maxPitch = 20, arc = 360 },
	fx = { muzzle = "flash_large", impact = "explosion_medium", sound = "cannon_heavy" },
}
