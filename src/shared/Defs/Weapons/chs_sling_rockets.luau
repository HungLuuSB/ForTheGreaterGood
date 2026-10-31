--!strict
-- Sling's rocket barrage (S-230; BAR's cormh).
return {
	id = "chs_sling_rockets",
	type = "BALLISTIC",
	range = 180,
	reload = 6,
	salvo = { count = 6, delay = 0.2 },
	projectileSpeed = 160,
	gravity = 60,
	highArc = true,
	accuracy = 2,
	damage = { LIGHT = 62, ARMORED = 62, STRUCTURE = 72, SHIP = 53, AIR = 0, SUB = 0 },
	aoe = 10,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARTILLERY", "STRUCTURE", "GROUND" },
	turret = { yawRate = 45, pitchRate = 35, tolerance = 2, minPitch = 20, maxPitch = 85, arc = 360 },
	fx = { muzzle = "flash_large", trail = "smoke_small", impact = "explosion_medium", sound = "mortar" },
}
