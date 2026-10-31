--!strict
-- Courser's rapid-fire light gun (S-230; BAR's armflash).
return {
	id = "ord_courser_gun",
	type = "BALLISTIC",
	range = 55,
	reload = 0.4,
	projectileSpeed = 520,
	gravity = 50,
	accuracy = 0.7,
	damage = { LIGHT = 34, ARMORED = 31, STRUCTURE = 25, SHIP = 26, AIR = 0, SUB = 0 },
	aoe = 2,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "LIGHT", "GROUND", "STRUCTURE" },
	turret = { yawRate = 140, pitchRate = 50, tolerance = 3, minPitch = -10, maxPitch = 20, arc = 360 },
	fx = { muzzle = "flash_medium", impact = "explosion_small", sound = "cannon_light" },
}
