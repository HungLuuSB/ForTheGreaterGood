--!strict
-- Strategic bomber payload.
return {
	id = "ord_heavy_bomb",
	type = "BALLISTIC",
	range = 140,
	reload = 2.5,
	projectileSpeed = 60,
	gravity = 60,
	accuracy = 2,
	damage = { LIGHT = 810, ARMORED = 720, STRUCTURE = 1080, SHIP = 810, AIR = 0, SUB = 0 },
	aoe = 22,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "ARMORED", "GROUND" },
	turret = { yawRate = 360, pitchRate = 360, tolerance = 30, minPitch = -90, maxPitch = 0, arc = 360 },
	fx = { impact = "explosion_huge", sound = "bomb_heavy" },
}
