--!strict
-- Thug's plasma cannon (S-181, the playtest's new units).
return {
	id = "chs_thug_cannon",
	type = "BALLISTIC",
	range = 70,
	reload = 1.4,
	projectileSpeed = 280,
	gravity = 60,
	accuracy = 0.8,
	damage = { LIGHT = 120, ARMORED = 105, STRUCTURE = 90, SHIP = 100, AIR = 0, SUB = 0 },
	aoe = 8,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 300, pitchRate = 120, tolerance = 3, minPitch = -20, maxPitch = 30, arc = 360 },
	fx = { trail = "plasma", color = { r = 255, g = 120, b = 30 }, impact = "plasma_hit", sound = "plasma_heavy" },
}
