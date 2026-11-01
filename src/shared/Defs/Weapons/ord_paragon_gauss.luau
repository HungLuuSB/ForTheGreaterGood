--!strict
-- Paragon's gauss (S-233, batch 2; BAR's armmar).
return {
	id = "ord_paragon_gauss",
	type = "BALLISTIC",
	range = 120,
	reload = 0.9,
	projectileSpeed = 500,
	gravity = 30,
	accuracy = 0.6,
	damage = { LIGHT = 260, ARMORED = 230, STRUCTURE = 210, SHIP = 220, AIR = 0, SUB = 0 },
	aoe = 3,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 180, pitchRate = 90, tolerance = 3, minPitch = -15, maxPitch = 30, arc = 360 },
	fx = { muzzle = "flash_large", impact = "explosion_medium", sound = "cannon_heavy" },
}
