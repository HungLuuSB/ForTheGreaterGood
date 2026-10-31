--!strict
-- Grendel's heavy cannon (S-230; BAR's corparrow).
return {
	id = "chs_grendel_cannon",
	type = "BALLISTIC",
	range = 180,
	reload = 2,
	projectileSpeed = 420,
	gravity = 50,
	accuracy = 0.7,
	damage = { LIGHT = 340, ARMORED = 360, STRUCTURE = 288, SHIP = 306, AIR = 0, SUB = 0 },
	aoe = 6,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 90, pitchRate = 50, tolerance = 3, minPitch = -10, maxPitch = 20, arc = 360 },
	fx = { muzzle = "flash_large", impact = "explosion_medium", sound = "cannon_heavy" },
}
