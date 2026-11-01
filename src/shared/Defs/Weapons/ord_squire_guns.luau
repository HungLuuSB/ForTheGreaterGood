--!strict
-- Squire's guns (S-233, batch 2; BAR's armpw).
return {
	id = "ord_squire_guns",
	type = "BALLISTIC",
	range = 64,
	reload = 0.4,
	projectileSpeed = 270,
	gravity = 50,
	accuracy = 1.5,
	damage = { LIGHT = 30, ARMORED = 27, STRUCTURE = 24, SHIP = 26, AIR = 0, SUB = 0 },
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "LIGHT", "GROUND", "STRUCTURE" },
	turret = { yawRate = 300, pitchRate = 120, tolerance = 4, minPitch = -20, maxPitch = 30, arc = 360 },
	fx = { trail = "plasma", color = { r = 255, g = 225, b = 120 }, impact = "explosion_small", sound = "plasma_light" },
}
