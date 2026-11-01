--!strict
-- Cutpurse's blaster (S-233, batch 2; BAR's cormando).
return {
	id = "chs_cutpurse_blaster",
	type = "HITSCAN",
	range = 110,
	reload = 0.64,
	damage = { LIGHT = 110, ARMORED = 99, STRUCTURE = 88, SHIP = 94, AIR = 0, SUB = 0 },
	aoe = 8,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "LIGHT", "GROUND", "STRUCTURE" },
	turret = { yawRate = 180, pitchRate = 90, tolerance = 3, minPitch = -15, maxPitch = 30, arc = 360 },
	fx = { muzzle = "flash_small", impact = "laser_hit", sound = "laser" },
}
