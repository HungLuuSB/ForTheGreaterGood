--!strict
-- Glaive's heavy laser (S-230; BAR's corhal).
return {
	id = "chs_glaive_laser",
	type = "HITSCAN",
	range = 95,
	reload = 1,
	damage = { LIGHT = 280, ARMORED = 300, STRUCTURE = 250, SHIP = 255, AIR = 0, SUB = 0 },
	aoe = 0,
	edgeEffectiveness = 0.5,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 120, pitchRate = 80, tolerance = 4, minPitch = -10, maxPitch = 25, arc = 360 },
	fx = { muzzle = "flash_small", impact = "spark", sound = "laser" },
}
