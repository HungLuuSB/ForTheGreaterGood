--!strict
-- Bomber bomb: dropped from altitude (ballistic, falls under gravity).
return {
	id = "chs_bomb",
	type = "BALLISTIC",
	range = 130,
	reload = 1.5,
	projectileSpeed = 60,
	gravity = 60,
	accuracy = 2,
	damage = { LIGHT = 462, ARMORED = 418, STRUCTURE = 550, SHIP = 440, AIR = 0, SUB = 0 },
	aoe = 14,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "ARMORED", "GROUND" },
	turret = { yawRate = 360, pitchRate = 360, tolerance = 30, minPitch = -90, maxPitch = 0, arc = 360 },
	fx = { impact = "explosion_large", sound = "bomb" },
}
