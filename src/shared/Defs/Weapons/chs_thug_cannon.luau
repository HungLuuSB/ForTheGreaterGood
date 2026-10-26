--!strict
-- Thug's plasma cannon (S-181, the playtest's new units).
-- S-190, the user: no blast (direct hits only), the tank shell's colour and small hit.
return {
	id = "chs_thug_cannon",
	type = "BALLISTIC",
	range = 70,
	reload = 1.4,
	projectileSpeed = 280,
	gravity = 60,
	accuracy = 0.8,
	damage = { LIGHT = 120, ARMORED = 105, STRUCTURE = 90, SHIP = 100, AIR = 0, SUB = 0 },
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 300, pitchRate = 120, tolerance = 3, minPitch = -20, maxPitch = 30, arc = 360 },
	fx = { trail = "plasma", color = { r = 255, g = 225, b = 120 }, impact = "explosion_small", sound = "plasma_heavy" },
}
