--!strict
-- Destroyer anti-submarine torpedo: acoustic homing, stays in the water (guide 12.3).
return {
	id = "chs_asw_torpedo",
	type = "TORPEDO",
	range = 280,
	reload = 3,
	projectileSpeed = 90,
	accuracy = 1,
	turnRate = 70,
	guidance = "ACOUSTIC",
	damage = { LIGHT = 0, ARMORED = 0, STRUCTURE = 0, SHIP = 190, AIR = 0, SUB = 300 },
	aoe = 4,
	edgeEffectiveness = 0.5,
	targets = { "NAVAL", "SUB" },
	priority = { "SUB", "NAVAL" },
	turret = { yawRate = 180, pitchRate = 180, tolerance = 20, minPitch = -90, maxPitch = 90, arc = 360 },
	fx = { muzzle = "torpedo_launch", trail = "bubbles", impact = "explosion_water", sound = "torpedo" },
}
