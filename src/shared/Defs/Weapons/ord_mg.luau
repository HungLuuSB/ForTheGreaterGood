--!strict
-- Scout machine gun: fast, light, short range.
return {
	id = "ord_mg",
	type = "BALLISTIC",
	range = 88, -- halved (S-152, the user: "Scout attack range's is too big"); 175 since the faction pass (S-62)
	reload = 0.45, -- faction pass (S-62)
	projectileSpeed = 600,
	gravity = 20,
	accuracy = 1.35, -- faction pass, tuned (S-62)
	damage = { LIGHT = 40, ARMORED = 16, STRUCTURE = 10, SHIP = 11, AIR = 0, SUB = 0 },
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "LIGHT", "GROUND" },
	turret = { yawRate = 240, pitchRate = 120, tolerance = 6, minPitch = -10, maxPitch = 30, arc = 360 },
	fx = { muzzle = "flash_small", impact = "sparks", sound = "mg" },
}
