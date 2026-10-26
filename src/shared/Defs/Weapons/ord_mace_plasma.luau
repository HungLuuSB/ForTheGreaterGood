--!strict
-- Mace's plasma: a slow, long lob (S-181, the playtest's new units).
-- S-190, the user: no blast (direct hits only), the tank shell's colour and small hit.
return {
	id = "ord_mace_plasma",
	type = "BALLISTIC",
	range = 125,
	reload = 2,
	projectileSpeed = 120,
	gravity = 60,
	accuracy = 1,
	damage = { LIGHT = 110, ARMORED = 95, STRUCTURE = 80, SHIP = 90, AIR = 0, SUB = 0 },
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 240, pitchRate = 120, tolerance = 3, minPitch = -20, maxPitch = 45, arc = 360 },
	fx = { trail = "plasma", color = { r = 255, g = 225, b = 120 }, impact = "explosion_small", sound = "plasma_heavy" },
}
