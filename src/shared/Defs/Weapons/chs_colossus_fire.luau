--!strict
-- Colossus's main cannon (S-236, the user's FTGG-FEEDBACK-5): it fires the
-- Commander's D-Gun bolt by itself, every 2 s. The bolt rides the ground in
-- a straight line for its range and deals 9000 to every enemy it passes
-- through (not the D-Gun's kill: no Commander exception, wrecks as usual).
return {
	id = "chs_colossus_fire",
	type = "BALLISTIC",
	bolt = 10, -- studs either side of its path (the D-Gun's is 7)
	range = 300,
	reload = 2,
	projectileSpeed = 120,
	gravity = 0,
	accuracy = 0,
	damage = { LIGHT = 9000, ARMORED = 9000, STRUCTURE = 9000, SHIP = 9000, AIR = 0, SUB = 0 },
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 90, pitchRate = 60, tolerance = 3, minPitch = -45, maxPitch = 45, arc = 360 },
	fx = { trail = "dgun", color = { r = 255, g = 200, b = 90 }, muzzle = "flash_large", impact = "dgun_hit", sound = "dgun" },
}
