--!strict
-- Glint's arm lasers: quick red pulses, one arm then the other (S-181, the playtest's new units).
return {
	id = "ord_glint_laser",
	type = "HITSCAN",
	range = 50,
	closeDamage = 1.5,
	reload = 0.4,
	shotCost = { power = 2 }, -- lasers cost energy per shot (S-187, the user)
	accuracy = 0.4,
	damage = { LIGHT = 30, ARMORED = 14, STRUCTURE = 8, SHIP = 12, AIR = 0, SUB = 0 },
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "LIGHT", "GROUND", "STRUCTURE" },
	turret = { yawRate = 360, pitchRate = 180, tolerance = 4, minPitch = -30, maxPitch = 40, arc = 360 },
	fx = { tracer = "laser", color = { r = 255, g = 60, b = 60 }, impact = "laser_hit", sound = "laser" },
}
