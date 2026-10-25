--!strict
-- Guard's red laser (S-157): Sentry's Chaos counterpart, shorter and quicker.
-- S-179, the playtest's balance notes: a T1 defence's damage × 2 (too weak against T1 units)
return {
	id = "chs_guard_laser",
	type = "HITSCAN",
	range = 165,
	closeDamage = 1.5, -- lasers hit harder up close (S-178, the user)
	reload = 0.7,
	accuracy = 0.3,
	damage = { LIGHT = 92, ARMORED = 88, STRUCTURE = 56, SHIP = 72, AIR = 0, SUB = 0 },
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 130, pitchRate = 80, tolerance = 3, minPitch = -60, maxPitch = 60, arc = 360 },
	fx = { tracer = "laser", color = { r = 255, g = 40, b = 40 }, impact = "laser_hit", sound = "laser" },
}
