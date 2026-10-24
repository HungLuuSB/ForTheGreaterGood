--!strict
-- Talos's lobbed shell (S-157): Gauntlet's Chaos counterpart, shorter,
-- a little heavier and wider.
return {
	id = "chs_talos_shell",
	type = "BALLISTIC",
	range = 360,
	reload = 3.4,
	projectileSpeed = 155,
	gravity = 60,
	highArc = true,
	accuracy = 1.5,
	damage = { LIGHT = 250, ARMORED = 225, STRUCTURE = 290, SHIP = 195, AIR = 0, SUB = 0 },
	aoe = 12,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARTILLERY", "STRUCTURE", "GROUND" },
	turret = { yawRate = 45, pitchRate = 35, tolerance = 2, minPitch = 20, maxPitch = 85, arc = 360 },
	fx = { muzzle = "flash_large", trail = "smoke_small", impact = "explosion_medium", sound = "mortar" },
}
