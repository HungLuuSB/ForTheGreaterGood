--!strict
-- Sentry's red laser (S-157, the user: "a simple laser tower that shoot red laser"):
-- instant shots, modest damage; the T1 basic tower.
return {
	id = "ord_sentry_laser",
	type = "HITSCAN",
	range = 190,
	reload = 0.8,
	accuracy = 0.3,
	damage = { LIGHT = 50, ARMORED = 48, STRUCTURE = 30, SHIP = 40, AIR = 0, SUB = 0 },
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 120, pitchRate = 80, tolerance = 3, minPitch = -60, maxPitch = 60, arc = 360 },
	fx = { tracer = "laser", color = { r = 255, g = 40, b = 40 }, impact = "laser_hit", sound = "laser" },
}
