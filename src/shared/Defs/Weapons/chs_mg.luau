--!strict
-- Scout machine gun: fast, light, short range.
return {
	id = "chs_mg",
	type = "BALLISTIC",
	range = 150,
	reload = 0.4,
	projectileSpeed = 600,
	gravity = 20,
	accuracy = 1.5,
	damage = { LIGHT = 44, ARMORED = 16, STRUCTURE = 11, SHIP = 10, AIR = 0, SUB = 0 },
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "LIGHT", "GROUND" },
	turret = { yawRate = 240, pitchRate = 120, tolerance = 6, minPitch = -10, maxPitch = 30, arc = 360 },
	fx = { muzzle = "flash_small", impact = "sparks", sound = "mg" },
}
