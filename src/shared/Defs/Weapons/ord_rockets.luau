--!strict
-- Attack helicopter rockets: unguided, against ground and ships.
return {
	id = "ord_rockets",
	type = "BALLISTIC",
	range = 220,
	reload = 0.8,
	projectileSpeed = 300,
	gravity = 20,
	accuracy = 1.5,
	damage = { LIGHT = 170, ARMORED = 150, STRUCTURE = 130, SHIP = 140, AIR = 0, SUB = 0 },
	aoe = 6,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 180, pitchRate = 120, tolerance = 4, minPitch = -80, maxPitch = 10, arc = 120 },
	fx = { muzzle = "rocket_launch", trail = "smoke_thin", impact = "explosion_small", sound = "rockets" },
}
