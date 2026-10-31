--!strict
-- Whisper's light gauss gun (S-228; BAR's armgremlin cannon).
return {
	id = "ord_whisper_gauss",
	type = "BALLISTIC",
	range = 110,
	reload = 1.4,
	projectileSpeed = 600,
	gravity = 30,
	accuracy = 0.8,
	damage = { LIGHT = 150, ARMORED = 140, STRUCTURE = 110, SHIP = 100, AIR = 0, SUB = 0 },
	aoe = 3,
	edgeEffectiveness = 0.5,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "LIGHT", "GROUND", "STRUCTURE" },
	turret = { yawRate = 110, pitchRate = 60, tolerance = 3, minPitch = -10, maxPitch = 20, arc = 360 },
	fx = { muzzle = "flash_small", impact = "explosion_small", sound = "cannon_light" },
}
