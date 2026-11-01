--!strict
-- Abyssal's rockets (S-233, batch 2; BAR's corshiva).
return {
	id = "chs_abyssal_rockets",
	type = "BALLISTIC",
	range = 280,
	reload = 9,
	projectileSpeed = 200,
	gravity = 60,
	highArc = true,
	accuracy = 2,
	damage = { LIGHT = 830, ARMORED = 750, STRUCTURE = 660, SHIP = 710, AIR = 0, SUB = 0 },
	aoe = 7,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "GROUND" },
	turret = { yawRate = 60, pitchRate = 40, tolerance = 2, minPitch = 20, maxPitch = 85, arc = 360 },
	fx = { muzzle = "missile_launch_large", trail = "smoke_thick", impact = "explosion_medium", sound = "rockets" },
}
