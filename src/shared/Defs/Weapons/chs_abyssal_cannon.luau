--!strict
-- Abyssal's cannon (S-233, batch 2; BAR's corshiva).
return {
	id = "chs_abyssal_cannon",
	type = "BALLISTIC",
	range = 230,
	reload = 2.5,
	projectileSpeed = 260,
	gravity = 40,
	accuracy = 1,
	damage = { LIGHT = 670, ARMORED = 600, STRUCTURE = 540, SHIP = 570, AIR = 0, SUB = 0 },
	aoe = 12,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 90, pitchRate = 60, tolerance = 3, minPitch = -10, maxPitch = 30, arc = 360 },
	fx = { muzzle = "flash_large", impact = "explosion_medium", sound = "cannon_heavy" },
}
