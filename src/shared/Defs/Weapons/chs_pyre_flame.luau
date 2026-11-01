--!strict
-- Pyre's flame (S-233, batch 2; BAR's corpyro).
return {
	id = "chs_pyre_flame",
	type = "HITSCAN",
	range = 81,
	reload = 0.2,
	damage = { LIGHT = 41, ARMORED = 37, STRUCTURE = 33, SHIP = 35, AIR = 0, SUB = 0 },
	aoe = 5,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "LIGHT", "GROUND", "STRUCTURE" },
	turret = { yawRate = 200, pitchRate = 120, tolerance = 6, minPitch = -30, maxPitch = 20, arc = 360 },
	fx = { trail = "flame", color = { r = 255, g = 120, b = 20 }, impact = "fire_hit", sound = "flamethrower" },
}
