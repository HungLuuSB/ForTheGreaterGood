--!strict
-- Infernal's flame (S-233, batch 2; BAR's cordemon).
return {
	id = "chs_infernal_flame",
	type = "HITSCAN",
	range = 150,
	reload = 0.5,
	damage = { LIGHT = 640, ARMORED = 580, STRUCTURE = 510, SHIP = 540, AIR = 0, SUB = 0 },
	aoe = 10,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "LIGHT", "ARMORED", "STRUCTURE" },
	turret = { yawRate = 200, pitchRate = 120, tolerance = 6, minPitch = -30, maxPitch = 20, arc = 360 },
	fx = { trail = "flame", color = { r = 255, g = 120, b = 20 }, impact = "fire_hit", sound = "flamethrower" },
}
