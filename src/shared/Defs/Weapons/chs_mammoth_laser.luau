--!strict
-- Mammoth's twin green lasers (S-209, H41: "the one found on Warden"; the
-- green laser is Chaos's Geryon / Bulwark laser): left, right, left, two
-- heavy shots a second.
return {
	id = "chs_mammoth_laser",
	type = "HITSCAN",
	range = 230,
	closeDamage = 1.5,
	reload = 0.5,
	shotCost = { power = 20 },
	accuracy = 0.3,
	damage = { LIGHT = 230, ARMORED = 210, STRUCTURE = 140, SHIP = 170, AIR = 0, SUB = 0 },
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "LIGHT", "ARMORED", "GROUND" },
	turret = { yawRate = 70, pitchRate = 50, tolerance = 3, minPitch = -20, maxPitch = 30, arc = 360 },
	fx = { tracer = "laser", color = { r = 60, g = 255, b = 90 }, impact = "laser_hit", sound = "laser" },
}
