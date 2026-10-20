--!strict
-- Hellmouth's gun: heavy, inaccurate ballistic mortar that may target radar contacts.
return {
	id = "chs_mortar",
	type = "BALLISTIC",
	range = 400,
	reload = 3.5,
	projectileSpeed = 210,
	gravity = 60,
	accuracy = 1.6,
	damage = { LIGHT = 360, ARMORED = 320, STRUCTURE = 440, SHIP = 280, AIR = 0, SUB = 0 },
	aoe = 14,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "ARTILLERY", "GROUND" },
	turret = { yawRate = 35, pitchRate = 28, tolerance = 2.5, minPitch = -5, maxPitch = 60, arc = 360 },
	canTargetRadar = true,
	fx = { muzzle = "flash_large", impact = "explosion_medium", sound = "mortar" },
}
