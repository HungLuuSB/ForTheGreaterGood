--!strict
-- Wrath's rocket (S-233, batch 2; BAR's corhrk).
return {
	id = "chs_wrath_rocket",
	type = "BALLISTIC",
	range = 300,
	reload = 10,
	projectileSpeed = 200,
	gravity = 60,
	highArc = true,
	accuracy = 2,
	damage = { LIGHT = 940, ARMORED = 850, STRUCTURE = 750, SHIP = 800, AIR = 0, SUB = 0 },
	aoe = 8,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "GROUND" },
	turret = { yawRate = 60, pitchRate = 40, tolerance = 2, minPitch = 20, maxPitch = 85, arc = 360 },
	fx = { muzzle = "missile_launch_large", trail = "smoke_thick", impact = "explosion_medium", sound = "rockets" },
}
