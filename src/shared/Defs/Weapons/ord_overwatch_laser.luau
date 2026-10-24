--!strict
-- Overwatch's green lasers (S-157, the user: "2 gun barrels that shoot
-- left-right-left, faster, deal more damage, more range"): the slot's two
-- muzzles take turns; the reload is the time between barrels.
return {
	id = "ord_overwatch_laser",
	type = "HITSCAN",
	range = 240,
	reload = 0.4,
	accuracy = 0.3,
	damage = { LIGHT = 62, ARMORED = 58, STRUCTURE = 40, SHIP = 48, AIR = 0, SUB = 0 },
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 120, pitchRate = 80, tolerance = 3, minPitch = -60, maxPitch = 30, arc = 360 },
	fx = { tracer = "laser", color = { r = 60, g = 255, b = 90 }, impact = "laser_hit", sound = "laser" },
}
