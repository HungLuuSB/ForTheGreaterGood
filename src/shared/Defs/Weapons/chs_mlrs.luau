--!strict
-- MLRS rockets: long-range saturation, inaccurate; can fire at radar contacts.
return {
	id = "chs_mlrs",
	type = "BALLISTIC",
	range = 480,
	reload = 6,
	projectileSpeed = 260,
	gravity = 60,
	accuracy = 3,
	damage = { LIGHT = 286, ARMORED = 220, STRUCTURE = 264, SHIP = 180, AIR = 0, SUB = 0 },
	aoe = 16,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "GROUND" },
	turret = { yawRate = 40, pitchRate = 30, tolerance = 3, minPitch = 0, maxPitch = 60, arc = 360 },
	canTargetRadar = true,
	fx = { muzzle = "rocket_launch", trail = "smoke_thick", impact = "explosion_medium", sound = "mlrs" },
}
