--!strict
-- Titan's close-quarters blasters (S-209, H40): plasma bolts with a wide blast, one arm then the other.
return {
	id = "ord_titan_blaster",
	type = "BALLISTIC",
	range = 160,
	reload = 0.8,
	projectileSpeed = 260,
	gravity = 30,
	accuracy = 0.8,
	damage = { LIGHT = 260, ARMORED = 200, STRUCTURE = 180, SHIP = 180, AIR = 0, SUB = 0 },
	aoe = 28,
	edgeEffectiveness = 0.5,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "LIGHT", "GROUND", "STRUCTURE" },
	turret = { yawRate = 120, pitchRate = 90, tolerance = 4, minPitch = -30, maxPitch = 40, arc = 360 },
	fx = { trail = "plasma", color = { r = 255, g = 225, b = 120 }, impact = "explosion_medium", sound = "plasma_heavy" },
}
