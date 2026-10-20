--!strict
-- Ship gun: ballistic, against ships, the coast and structures.
return {
	id = "chs_naval_gun",
	type = "BALLISTIC",
	range = 240,
	reload = 2.2,
	projectileSpeed = 360,
	gravity = 60,
	accuracy = 0.8,
	damage = { LIGHT = 180, ARMORED = 160, STRUCTURE = 180, SHIP = 190, AIR = 0, SUB = 0 },
	aoe = 6,
	edgeEffectiveness = 0.3,
	targets = { "NAVAL", "GROUND", "STRUCTURE" },
	priority = { "NAVAL", "STRUCTURE", "GROUND" },
	turret = { yawRate = 70, pitchRate = 40, tolerance = 3, minPitch = -10, maxPitch = 35, arc = 360 },
	fx = { muzzle = "flash_medium", impact = "explosion_medium", sound = "naval_gun" },
}
