--!strict
-- Submarine torpedo: acoustic homing, stays in the water (guide 12.3).
-- S-179, the playtest's balance notes: a T1 unit's range halved, damage × 0.8 (four Lancer shells no longer kill an extractor)
return {
	id = "chs_torpedo",
	type = "TORPEDO",
	range = 140,
	reload = 5,
	projectileSpeed = 90,
	accuracy = 1,
	turnRate = 70,
	guidance = "ACOUSTIC",
	damage = { LIGHT = 0, ARMORED = 0, STRUCTURE = 0, SHIP = 256, AIR = 0, SUB = 184 },
	aoe = 4,
	edgeEffectiveness = 0.5,
	targets = { "NAVAL", "SUB" },
	priority = { "SUB", "NAVAL" },
	turret = { yawRate = 180, pitchRate = 180, tolerance = 20, minPitch = -90, maxPitch = 90, arc = 360 },
	fx = { muzzle = "torpedo_launch", trail = "bubbles", impact = "explosion_water", sound = "torpedo" },
}
