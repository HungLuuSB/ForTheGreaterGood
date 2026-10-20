--!strict
-- Verdict's gun: long-range ballistic artillery that may target radar contacts.
return {
	id = "ord_howitzer",
	type = "BALLISTIC",
	range = 450,
	reload = 4,
	projectileSpeed = 220,
	gravity = 60,
	accuracy = 0.6,
	damage = { LIGHT = 340, ARMORED = 300, STRUCTURE = 420, SHIP = 260, AIR = 0, SUB = 0 },
	aoe = 10,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "ARTILLERY", "GROUND" },
	turret = { yawRate = 40, pitchRate = 30, tolerance = 2, minPitch = -5, maxPitch = 60, arc = 360 },
	canTargetRadar = true,
	fx = { muzzle = "flash_large", impact = "explosion_medium", sound = "howitzer" },
}
