--!strict
-- Edict's gun (S-62): a fortified emplacement's howitzer, longer and harder hitting than the Verdict's.
return {
	id = "ord_fortress_howitzer",
	type = "BALLISTIC",
	range = 520, -- faction pass (S-62)
	reload = 4.4, -- faction pass (S-62)
	projectileSpeed = 220,
	gravity = 60,
	accuracy = 0.5, -- faction pass (S-62)
	damage = { LIGHT = 389, ARMORED = 343, STRUCTURE = 480, SHIP = 297, AIR = 0, SUB = 0 },
	aoe = 10,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "ARTILLERY", "GROUND" },
	turret = { yawRate = 40, pitchRate = 30, tolerance = 2, minPitch = -5, maxPitch = 60, arc = 360 },
	canTargetRadar = true,
	fx = { muzzle = "flash_large", impact = "explosion_medium", sound = "howitzer" },
}
