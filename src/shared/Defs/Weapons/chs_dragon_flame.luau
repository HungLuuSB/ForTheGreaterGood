--!strict
-- Dragon's fire gun: a stream of fire straight down onto the ground (S-181, the playtest's new units).
return {
	id = "chs_dragon_flame",
	type = "HITSCAN",
	range = 70,
	reload = 0.15,
	accuracy = 1,
	damage = { LIGHT = 60, ARMORED = 50, STRUCTURE = 70, SHIP = 55, AIR = 0, SUB = 0 },
	aoe = 8,
	edgeEffectiveness = 0.5,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "GROUND" },
	turret = { yawRate = 180, pitchRate = 180, tolerance = 6, minPitch = -90, maxPitch = -20, arc = 360 },
	fx = { trail = "flame", color = { r = 255, g = 120, b = 20 }, impact = "fire_hit", sound = "flamethrower" },
}
