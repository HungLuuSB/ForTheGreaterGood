--!strict
-- Gnat's light machine gun (S-230; BAR's corsh).
return {
	id = "chs_gnat_mg",
	type = "HITSCAN",
	range = 60,
	reload = 0.4,
	damage = { LIGHT = 24, ARMORED = 21, STRUCTURE = 10, SHIP = 18, AIR = 0, SUB = 0 },
	aoe = 0,
	edgeEffectiveness = 0.5,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "LIGHT", "GROUND", "STRUCTURE" },
	turret = { yawRate = 120, pitchRate = 80, tolerance = 4, minPitch = -10, maxPitch = 25, arc = 360 },
	fx = { muzzle = "flash_small", impact = "spark", sound = "mg" },
}
