--!strict
-- Mace's plasma: a slow, long lob (S-181, the playtest's new units).
return {
	id = "ord_mace_plasma",
	type = "BALLISTIC",
	range = 125,
	reload = 2,
	projectileSpeed = 120,
	gravity = 60,
	accuracy = 1,
	damage = { LIGHT = 110, ARMORED = 95, STRUCTURE = 80, SHIP = 90, AIR = 0, SUB = 0 },
	aoe = 6,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 240, pitchRate = 120, tolerance = 3, minPitch = -20, maxPitch = 45, arc = 360 },
	fx = { trail = "plasma", color = { r = 80, g = 160, b = 255 }, impact = "plasma_hit", sound = "plasma_heavy" },
}
