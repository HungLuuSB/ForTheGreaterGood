--!strict
-- MLRS rockets: long-range saturation, inaccurate; can fire at radar contacts.
return {
	id = "chs_mlrs",
	type = "BALLISTIC",
	range = 440, -- faction pass (S-62)
	reload = 4.5, -- faction pass, tuned (S-62)
	projectileSpeed = 260,
	gravity = 60,
	accuracy = 3.15, -- faction pass, tuned (S-62)
	damage = { LIGHT = 264, ARMORED = 250, STRUCTURE = 244, SHIP = 166, AIR = 0, SUB = 0 },
	aoe = 16,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "GROUND" },
	turret = { yawRate = 40, pitchRate = 30, tolerance = 3, minPitch = 0, maxPitch = 60, arc = 360 },
	canTargetRadar = true,
	fx = { muzzle = "rocket_launch", trail = "smoke_thick", impact = "explosion_medium", sound = "mlrs" },
}
