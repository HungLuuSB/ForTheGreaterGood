--!strict
-- The Sovereign's arm laser (S-194, the user's G5: "arms commander with a laser gun"):
-- a short, quick laser that defends it while it builds.
return {
	id = "ord_sovereign_laser",
	type = "HITSCAN",
	range = 120,
	closeDamage = 1.5, -- lasers hit harder up close (S-178)
	reload = 0.6,
	shotCost = { power = 10 }, -- lasers cost energy per shot (S-187)
	accuracy = 0.3,
	damage = { LIGHT = 60, ARMORED = 50, STRUCTURE = 40, SHIP = 45, AIR = 0, SUB = 0 },
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "GROUND", "NAVAL", "STRUCTURE" },
	turret = { yawRate = 200, pitchRate = 120, tolerance = 4, minPitch = -45, maxPitch = 45, arc = 360 },
	fx = { tracer = "laser", color = { r = 120, g = 190, b = 255 }, impact = "laser_hit", sound = "laser" },
}
