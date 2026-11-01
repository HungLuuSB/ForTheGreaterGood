--!strict
-- Martyr's trigger (S-233, batch 2; BAR's armvader).
return {
	id = "ord_martyr_trigger",
	type = "HITSCAN",
	range = 8,
	reload = 1,
	kamikaze = true, -- (S-233) detonates: the unit's deathBlast does the damage
	damage = { LIGHT = 1100, ARMORED = 990, STRUCTURE = 880, SHIP = 940, AIR = 0, SUB = 0 },
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 300, pitchRate = 120, tolerance = 4, minPitch = -20, maxPitch = 30, arc = 360 },
	fx = { impact = "explosion_small" },
}
