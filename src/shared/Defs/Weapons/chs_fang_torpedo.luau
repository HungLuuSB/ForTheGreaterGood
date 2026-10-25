--!strict
-- Split from chs_torpedo (S-179, the playtest's balance notes) so its users can be balanced apart.
-- Submarine torpedo: acoustic homing, stays in the water (guide 12.3).
-- S-179, the playtest's balance notes: a T1 defence's damage × 2 (too weak against T1 units)
return {
	id = "chs_fang_torpedo",
	type = "TORPEDO",
	range = 280,
	reload = 5,
	projectileSpeed = 90,
	accuracy = 1,
	turnRate = 70,
	guidance = "ACOUSTIC",
	damage = { LIGHT = 0, ARMORED = 0, STRUCTURE = 0, SHIP = 640, AIR = 0, SUB = 460 },
	aoe = 4,
	edgeEffectiveness = 0.5,
	targets = { "NAVAL", "SUB" },
	priority = { "SUB", "NAVAL" },
	turret = { yawRate = 180, pitchRate = 180, tolerance = 20, minPitch = -90, maxPitch = 90, arc = 360 },
	fx = { muzzle = "torpedo_launch", trail = "bubbles", impact = "explosion_water", sound = "torpedo" },
}
