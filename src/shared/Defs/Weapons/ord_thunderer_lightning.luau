--!strict
-- Thunderer's heavy lightning cannon (S-229; BAR's armthor): an instant bolt.
return {
	id = "ord_thunderer_lightning",
	type = "HITSCAN",
	range = 300,
	reload = 1.2,
	damage = { LIGHT = 840, ARMORED = 840, STRUCTURE = 700, SHIP = 840, AIR = 0, SUB = 0 },
	aoe = 8,
	edgeEffectiveness = 0.5,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 45, pitchRate = 30, tolerance = 4, minPitch = -10, maxPitch = 20, arc = 360 },
	fx = { muzzle = "flash_large", impact = "explosion_medium", sound = "cannon_heavy" },
}
