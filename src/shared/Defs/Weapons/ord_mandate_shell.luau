--!strict
-- Mandate's long-range plasma shell (S-230; BAR's armmart).
return {
	id = "ord_mandate_shell",
	type = "BALLISTIC",
	range = 260,
	reload = 4,
	projectileSpeed = 160,
	gravity = 60,
	highArc = true,
	accuracy = 2,
	damage = { LIGHT = 320, ARMORED = 300, STRUCTURE = 330, SHIP = 255, AIR = 0, SUB = 0 },
	aoe = 16,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARTILLERY", "STRUCTURE", "GROUND" },
	turret = { yawRate = 45, pitchRate = 35, tolerance = 2, minPitch = 20, maxPitch = 85, arc = 360 },
	fx = { muzzle = "flash_large", trail = "smoke_small", impact = "explosion_medium", sound = "mortar" },
}
