--!strict
-- Colossus's fire (S-233, batch 2; BAR's corjugg).
return {
	id = "chs_colossus_fire",
	type = "BALLISTIC",
	range = 210,
	reload = 5,
	projectileSpeed = 300,
	gravity = 30,
	accuracy = 1,
	damage = { LIGHT = 1300, ARMORED = 1200, STRUCTURE = 1000, SHIP = 1100, AIR = 0, SUB = 0 },
	aoe = 8,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 90, pitchRate = 60, tolerance = 3, minPitch = -10, maxPitch = 30, arc = 360 },
	fx = { muzzle = "flash_large", impact = "explosion_medium", sound = "cannon_heavy" },
}
