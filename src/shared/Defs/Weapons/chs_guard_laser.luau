--!strict
-- Guard's red laser (S-157): Sentry's Chaos counterpart, shorter and quicker.
return {
	id = "chs_guard_laser",
	type = "HITSCAN",
	range = 165,
	reload = 0.7,
	accuracy = 0.3,
	damage = { LIGHT = 46, ARMORED = 44, STRUCTURE = 28, SHIP = 36, AIR = 0, SUB = 0 },
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 130, pitchRate = 80, tolerance = 3, minPitch = -60, maxPitch = 30, arc = 360 },
	fx = { tracer = "laser", color = { r = 255, g = 40, b = 40 }, impact = "laser_hit", sound = "laser" },
}
