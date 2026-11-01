--!strict
-- Pustule's trigger (S-233, batch 2; BAR's corsktl).
return {
	id = "chs_pustule_trigger",
	type = "HITSCAN",
	range = 8,
	reload = 1,
	kamikaze = true, -- (S-233) detonates: the unit's deathBlast does the damage
	damage = { LIGHT = 4000, ARMORED = 3600, STRUCTURE = 3200, SHIP = 3400, AIR = 0, SUB = 0 },
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 300, pitchRate = 120, tolerance = 4, minPitch = -20, maxPitch = 30, arc = 360 },
	fx = { impact = "explosion_small" },
}
