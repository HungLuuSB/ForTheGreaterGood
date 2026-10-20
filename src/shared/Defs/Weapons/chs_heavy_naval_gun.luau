--!strict
-- Cruiser / coastal battery main gun.
return {
	id = "chs_heavy_naval_gun",
	type = "BALLISTIC",
	range = 420,
	reload = 3.5,
	projectileSpeed = 380,
	gravity = 60,
	accuracy = 0.8,
	damage = { LIGHT = 462, ARMORED = 418, STRUCTURE = 495, SHIP = 528, AIR = 0, SUB = 0 },
	aoe = 10,
	edgeEffectiveness = 0.35,
	targets = { "NAVAL", "GROUND", "STRUCTURE" },
	priority = { "NAVAL", "STRUCTURE", "GROUND" },
	turret = { yawRate = 40, pitchRate = 30, tolerance = 2, minPitch = -10, maxPitch = 40, arc = 360 },
	fx = { muzzle = "flash_huge", impact = "explosion_large", sound = "naval_gun_heavy" },
}
