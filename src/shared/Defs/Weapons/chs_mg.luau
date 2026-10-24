--!strict
-- Scout machine gun: fast, light, short range.
return {
	id = "chs_mg",
	type = "BALLISTIC",
	range = 70, -- halved (S-152, the user: "Scout attack range's is too big"); 140 since the faction pass (S-62)
	reload = 0.35, -- faction pass (S-62)
	projectileSpeed = 600,
	gravity = 20,
	accuracy = 1.65, -- faction pass, tuned (S-62)
	damage = { LIGHT = 34, ARMORED = 14, STRUCTURE = 9, SHIP = 8, AIR = 0, SUB = 0 },
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "LIGHT", "GROUND" },
	turret = { yawRate = 240, pitchRate = 120, tolerance = 6, minPitch = -10, maxPitch = 30, arc = 360 },
	fx = { muzzle = "flash_small", impact = "sparks", sound = "mg" },
}
