--!strict
-- Sentry's red laser (S-157, the user: "a simple laser tower that shoot red laser"):
-- instant shots, modest damage; the T1 basic tower.
-- S-179, the playtest's balance notes: a T1 defence's damage × 2 (too weak against T1 units)
return {
	id = "ord_sentry_laser",
	type = "HITSCAN",
	range = 190,
	closeDamage = 1.5, -- lasers hit harder up close (S-178, the user)
	reload = 0.8,
	accuracy = 0.3,
	damage = { LIGHT = 100, ARMORED = 96, STRUCTURE = 60, SHIP = 80, AIR = 0, SUB = 0 },
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 120, pitchRate = 80, tolerance = 3, minPitch = -60, maxPitch = 60, arc = 360 },
	fx = { tracer = "laser", color = { r = 255, g = 40, b = 40 }, impact = "laser_hit", sound = "laser" },
}
