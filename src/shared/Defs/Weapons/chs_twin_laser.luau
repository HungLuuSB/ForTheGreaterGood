--!strict
-- Twin Guard's red lasers (S-157, the user: "like 2 Guard barrel in 1 tower
-- with more range"): Guard's shot from two barrels in turn.
-- S-179, the playtest's balance notes: a T1 defence's damage × 2 (too weak against T1 units)
return {
	id = "chs_twin_laser",
	type = "HITSCAN",
	range = 195,
	closeDamage = 1.5, -- lasers hit harder up close (S-178, the user)
	reload = 0.45,
	shotCost = { power = 12 }, -- lasers cost energy per shot (S-187, the user)
	accuracy = 0.3,
	damage = { LIGHT = 92, ARMORED = 88, STRUCTURE = 56, SHIP = 72, AIR = 0, SUB = 0 },
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 130, pitchRate = 80, tolerance = 3, minPitch = -60, maxPitch = 60, arc = 360 },
	fx = { tracer = "laser", color = { r = 255, g = 40, b = 40 }, impact = "laser_hit", sound = "laser" },
}
