--!strict
-- Culverin's mortar (S-233, batch 2; BAR's armfido).
return {
	id = "ord_culverin_mortar",
	type = "BALLISTIC",
	range = 230,
	reload = 4.2,
	projectileSpeed = 150,
	gravity = 60,
	highArc = true,
	accuracy = 2,
	damage = { LIGHT = 280, ARMORED = 250, STRUCTURE = 220, SHIP = 240, AIR = 0, SUB = 0 },
	aoe = 8,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "GROUND" },
	turret = { yawRate = 60, pitchRate = 40, tolerance = 2, minPitch = 20, maxPitch = 85, arc = 360 },
	fx = { muzzle = "flash_large", trail = "smoke_small", impact = "explosion_medium", sound = "mortar" },
}
