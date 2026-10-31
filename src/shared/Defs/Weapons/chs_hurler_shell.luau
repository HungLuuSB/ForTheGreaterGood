--!strict
-- Hurler's plasma shell (S-230; BAR's cormart).
return {
	id = "chs_hurler_shell",
	type = "BALLISTIC",
	range = 250,
	reload = 4,
	projectileSpeed = 160,
	gravity = 60,
	highArc = true,
	accuracy = 2,
	damage = { LIGHT = 310, ARMORED = 290, STRUCTURE = 320, SHIP = 246, AIR = 0, SUB = 0 },
	aoe = 18,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARTILLERY", "STRUCTURE", "GROUND" },
	turret = { yawRate = 45, pitchRate = 35, tolerance = 2, minPitch = 20, maxPitch = 85, arc = 360 },
	fx = { muzzle = "flash_large", trail = "smoke_small", impact = "explosion_medium", sound = "mortar" },
}
