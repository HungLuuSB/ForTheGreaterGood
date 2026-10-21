--!strict
-- Hellmouth's gun: heavy, inaccurate ballistic mortar that may target radar contacts.
return {
	id = "chs_mortar",
	type = "BALLISTIC",
	range = 380, -- faction pass (S-62)
	reload = 3, -- faction pass (S-62)
	projectileSpeed = 210,
	gravity = 60,
	accuracy = 2, -- faction pass (S-62)
	damage = { LIGHT = 295, ARMORED = 262, STRUCTURE = 360, SHIP = 229, AIR = 0, SUB = 0 },
	aoe = 14,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "ARTILLERY", "GROUND" },
	turret = { yawRate = 35, pitchRate = 28, tolerance = 2.5, minPitch = -5, maxPitch = 60, arc = 360 },
	canTargetRadar = true,
	fx = { muzzle = "flash_large", impact = "explosion_medium", sound = "mortar" },
}
