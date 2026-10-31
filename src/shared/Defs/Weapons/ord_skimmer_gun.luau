--!strict
-- Skimmer's plasma gun (S-230; BAR's armanac).
return {
	id = "ord_skimmer_gun",
	type = "BALLISTIC",
	range = 110,
	reload = 1.6,
	projectileSpeed = 450,
	gravity = 50,
	accuracy = 0.7,
	damage = { LIGHT = 98, ARMORED = 98, STRUCTURE = 78, SHIP = 83, AIR = 0, SUB = 0 },
	aoe = 4,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 90, pitchRate = 50, tolerance = 3, minPitch = -10, maxPitch = 20, arc = 360 },
	fx = { muzzle = "flash_medium", impact = "explosion_small", sound = "cannon_light" },
}
