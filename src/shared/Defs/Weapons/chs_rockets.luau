--!strict
-- Attack helicopter rockets: unguided, against ground and ships.
-- S-179, the playtest's balance notes: a T1 unit's range halved, damage × 0.8 (four Lancer shells no longer kill an extractor)
return {
	id = "chs_rockets",
	type = "BALLISTIC",
	rocket = true, -- point defence intercepts it (S-149)
	range = 100,
	reload = 0.8,
	projectileSpeed = 300,
	gravity = 20,
	accuracy = 1.5,
	damage = { LIGHT = 160, ARMORED = 144, STRUCTURE = 128, SHIP = 136, AIR = 0, SUB = 0 },
	aoe = 6,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 180, pitchRate = 120, tolerance = 4, minPitch = -80, maxPitch = 10, arc = 120 },
	fx = { muzzle = "rocket_launch", trail = "smoke_thin", impact = "explosion_small", sound = "rockets" },
}
