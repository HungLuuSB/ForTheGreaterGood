--!strict
-- Monolith's cannon (S-233, batch 2; BAR's armvang).
return {
	id = "ord_monolith_cannon",
	type = "BALLISTIC",
	range = 420,
	reload = 10,
	projectileSpeed = 170, -- (still reaches 420: v² ≥ g × range)
	gravity = 60,
	highArc = true,
	accuracy = 2.5,
	damage = { LIGHT = 1400, ARMORED = 1300, STRUCTURE = 1100, SHIP = 1200, AIR = 0, SUB = 0 },
	aoe = 20,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "GROUND" },
	turret = { yawRate = 60, pitchRate = 40, tolerance = 2, minPitch = 20, maxPitch = 85, arc = 360 },
	fx = { muzzle = "flash_large", trail = "smoke_small", impact = "explosion_medium", sound = "mortar" },
}
