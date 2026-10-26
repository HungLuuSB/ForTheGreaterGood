--!strict
-- Dragon's green lasers (S-181, the playtest's new units).
return {
	id = "chs_dragon_laser",
	type = "HITSCAN",
	range = 200,
	closeDamage = 1.5,
	reload = 0.6,
	shotCost = { power = 8 }, -- lasers cost energy per shot (S-187, the user)
	accuracy = 0.3,
	damage = { LIGHT = 90, ARMORED = 80, STRUCTURE = 60, SHIP = 75, AIR = 0, SUB = 0 },
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 150, pitchRate = 120, tolerance = 3, minPitch = -80, maxPitch = 10, arc = 360 },
	fx = { tracer = "laser", color = { r = 60, g = 255, b = 80 }, impact = "laser_hit", sound = "laser" },
}
