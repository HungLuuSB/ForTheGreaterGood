--!strict
-- Cleaver's riot cannon (S-230; BAR's corlevlr): wide splash against light units.
return {
	id = "chs_cleaver_cannon",
	type = "BALLISTIC",
	range = 95,
	reload = 1.6,
	projectileSpeed = 450,
	gravity = 50,
	accuracy = 0.7,
	damage = { LIGHT = 165, ARMORED = 147, STRUCTURE = 118, SHIP = 125, AIR = 0, SUB = 0 },
	aoe = 14,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "LIGHT", "GROUND", "STRUCTURE" },
	turret = { yawRate = 90, pitchRate = 50, tolerance = 3, minPitch = -10, maxPitch = 20, arc = 360 },
	fx = { muzzle = "flash_medium", impact = "explosion_small", sound = "cannon_light" },
}
