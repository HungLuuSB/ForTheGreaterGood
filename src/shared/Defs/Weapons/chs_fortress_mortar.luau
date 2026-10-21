--!strict
-- Cataclysm's gun (S-62): a fortified emplacement's mortar, longer and harder hitting than the Hellmouth's.
return {
	id = "chs_fortress_mortar",
	type = "BALLISTIC",
	range = 400,
	reload = 3, -- faction pass (S-62)
	projectileSpeed = 210,
	gravity = 60,
	accuracy = 2, -- faction pass (S-62)
	damage = { LIGHT = 327, ARMORED = 291, STRUCTURE = 400, SHIP = 255, AIR = 0, SUB = 0 },
	aoe = 14,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "ARTILLERY", "GROUND" },
	turret = { yawRate = 35, pitchRate = 28, tolerance = 2.5, minPitch = -5, maxPitch = 60, arc = 360 },
	canTargetRadar = true,
	fx = { muzzle = "flash_large", impact = "explosion_medium", sound = "mortar" },
}
