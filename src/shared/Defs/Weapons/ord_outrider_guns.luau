--!strict
-- Outrider's guns (S-233, batch 2; BAR's armfast).
return {
	id = "ord_outrider_guns",
	type = "BALLISTIC",
	range = 81,
	reload = 0.64,
	projectileSpeed = 270,
	gravity = 50,
	accuracy = 1.5,
	damage = { LIGHT = 65, ARMORED = 59, STRUCTURE = 52, SHIP = 55, AIR = 0, SUB = 0 },
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "LIGHT", "GROUND", "STRUCTURE" },
	turret = { yawRate = 300, pitchRate = 120, tolerance = 4, minPitch = -20, maxPitch = 30, arc = 360 },
	fx = { trail = "plasma", color = { r = 255, g = 225, b = 120 }, impact = "explosion_small", sound = "plasma_light" },
}
