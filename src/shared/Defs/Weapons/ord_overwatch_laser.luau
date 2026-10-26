--!strict
-- Overwatch's green lasers (S-157, the user: "2 gun barrels that shoot
-- left-right-left, faster, deal more damage, more range"): the slot's two
-- muzzles take turns; the reload is the time between barrels.
-- S-179, the playtest's balance notes: a T1 defence's damage × 2 (too weak against T1 units)
return {
	id = "ord_overwatch_laser",
	type = "HITSCAN",
	range = 240,
	closeDamage = 1.5, -- lasers hit harder up close (S-178, the user)
	reload = 0.4,
	shotCost = { power = 15 }, -- lasers cost energy per shot (S-187, the user)
	accuracy = 0.3,
	damage = { LIGHT = 124, ARMORED = 116, STRUCTURE = 80, SHIP = 96, AIR = 0, SUB = 0 },
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 120, pitchRate = 80, tolerance = 3, minPitch = -60, maxPitch = 60, arc = 360 },
	fx = { tracer = "laser", color = { r = 60, g = 255, b = 90 }, impact = "laser_hit", sound = "laser" },
}
