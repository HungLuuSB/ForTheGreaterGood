--!strict
-- The Sovereign's D-Gun (S-194, the user's G5): fired only on a DGUN order, a slow
-- bolt of hot plasma that rides the ground in a straight line for its range
-- and destroys everything it passes through, leaving no wreck (Commanders
-- lose half their health instead). Costs a lot of power per shot.
return {
	id = "ord_sovereign_dgun",
	type = "BALLISTIC",
	manualFire = true,
	bolt = 7, -- studs either side of its path: the D-Gun's bolt (S-194)
	range = 160,
	reload = 2,
	shotCost = { power = 500 },
	projectileSpeed = 70,
	gravity = 0,
	accuracy = 0,
	damage = { LIGHT = 100000, ARMORED = 100000, STRUCTURE = 100000, SHIP = 100000, AIR = 0, SUB = 0 },
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "GROUND", "NAVAL", "STRUCTURE" },
	turret = { yawRate = 200, pitchRate = 120, tolerance = 4, minPitch = -45, maxPitch = 45, arc = 360 },
	fx = { trail = "dgun", color = { r = 255, g = 200, b = 90 }, muzzle = "flash_large", impact = "dgun_hit", sound = "dgun" },
}
