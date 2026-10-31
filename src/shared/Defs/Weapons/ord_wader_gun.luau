--!strict
-- Wader's light gun (S-230; BAR's armpincer).
return {
	id = "ord_wader_gun",
	type = "BALLISTIC",
	range = 95,
	reload = 1.5,
	projectileSpeed = 450,
	gravity = 50,
	accuracy = 0.7,
	damage = { LIGHT = 100, ARMORED = 100, STRUCTURE = 80, SHIP = 85, AIR = 0, SUB = 0 },
	aoe = 4,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 90, pitchRate = 50, tolerance = 3, minPitch = -10, maxPitch = 20, arc = 360 },
	fx = { muzzle = "flash_medium", impact = "explosion_small", sound = "cannon_light" },
}
