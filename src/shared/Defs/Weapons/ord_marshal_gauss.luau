--!strict
-- Marshal's gauss (S-233, batch 2; BAR's armmav).
return {
	id = "ord_marshal_gauss",
	type = "BALLISTIC",
	range = 130,
	reload = 1.3,
	projectileSpeed = 500,
	gravity = 30,
	accuracy = 0.6,
	damage = { LIGHT = 290, ARMORED = 260, STRUCTURE = 230, SHIP = 250, AIR = 0, SUB = 0 },
	aoe = 3,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 180, pitchRate = 90, tolerance = 3, minPitch = -15, maxPitch = 30, arc = 360 },
	fx = { muzzle = "flash_medium", impact = "explosion_small", sound = "cannon_light" },
}
