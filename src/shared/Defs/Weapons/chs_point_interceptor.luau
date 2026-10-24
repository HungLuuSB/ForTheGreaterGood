--!strict
-- Basilisk interceptor: a point-defence interceptor (S-149, the user). It engages enemy
-- missiles and rockets flying near its unit, never units: one interceptor
-- per missile, and a burst destroys it with `intercepts.chance`. Its stock
-- refills one at a time; a big salvo empties it. Placeholder numbers.
return {
	id = "chs_point_interceptor",
	type = "HOMING",
	range = 420, -- the cover radius
	reload = 0.25, -- between interceptors
	projectileSpeed = 580,
	accuracy = 1,
	turnRate = 680,
	launch = "vertical",
	climbHeight = 14,
	stockpile = { capacity = 10, buildTime = 1.8, cost = { supply = 5, power = 70 } },
	guidance = "RADAR", -- (steers at the missile; units are never its targets)
	lockRange = 420,
	intercepts = { chance = 0.75, tactical = true },
	interceptOnly = true,
	terminalRange = 30,
	damage = { LIGHT = 0, ARMORED = 0, STRUCTURE = 0, SHIP = 0, AIR = 0, SUB = 0 },
	aoe = 10,
	edgeEffectiveness = 0.5,
	targets = { "AIR" }, -- (never used: interceptOnly)
	fx = { muzzle = "missile_launch_small", trail = "smoke_thin", impact = "explosion_air_small", sound = "sam_ir" },
}
