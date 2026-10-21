--!strict
-- Minotaur's gun (S-64): short and inaccurate, +50% against structures.
return {
	id = "chs_ram_cannon",
	type = "BALLISTIC",
	range = 160,
	reload = 2.2,
	salvo = { count = 1, delay = 0 },
	projectileSpeed = 360,
	gravity = 60,
	accuracy = 1.6,
	damage = { LIGHT = 240, ARMORED = 220, STRUCTURE = 360, SHIP = 200, AIR = 0, SUB = 0 },
	aoe = 6,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "ARMORED", "GROUND" },
	turret = { yawRate = 60, pitchRate = 40, tolerance = 4, minPitch = -10, maxPitch = 20, arc = 360 },
	fx = { muzzle = "flash_large", impact = "explosion_medium", sound = "cannon_heavy" },
}
