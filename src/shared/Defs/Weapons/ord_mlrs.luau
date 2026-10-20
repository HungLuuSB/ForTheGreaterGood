--!strict
-- MLRS rockets: long-range saturation, inaccurate; can fire at radar contacts.
return {
	id = "ord_mlrs",
	type = "BALLISTIC",
	range = 528,
	reload = 6,
	projectileSpeed = 260,
	gravity = 60,
	accuracy = 1.5,
	damage = { LIGHT = 234, ARMORED = 180, STRUCTURE = 216, SHIP = 180, AIR = 0, SUB = 0 },
	aoe = 16,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "GROUND" },
	turret = { yawRate = 40, pitchRate = 30, tolerance = 3, minPitch = 0, maxPitch = 60, arc = 360 },
	canTargetRadar = true,
	fx = { muzzle = "rocket_launch", trail = "smoke_thick", impact = "explosion_medium", sound = "mlrs" },
}
