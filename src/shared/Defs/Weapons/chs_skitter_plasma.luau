--!strict
-- Skitter's plasma: many small bolts (S-181, the playtest's new units).
return {
	id = "chs_skitter_plasma",
	type = "BALLISTIC",
	range = 45,
	reload = 0.25,
	projectileSpeed = 300,
	gravity = 30,
	accuracy = 1.5,
	damage = { LIGHT = 18, ARMORED = 8, STRUCTURE = 6, SHIP = 7, AIR = 0, SUB = 0 },
	aoe = 2,
	edgeEffectiveness = 0.5,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "LIGHT", "GROUND", "STRUCTURE" },
	turret = { yawRate = 360, pitchRate = 180, tolerance = 5, minPitch = -30, maxPitch = 40, arc = 360 },
	fx = { trail = "plasma", color = { r = 255, g = 225, b = 120 }, impact = "plasma_hit", sound = "plasma_light" }, -- the tank shell's colour (S-190)
}
