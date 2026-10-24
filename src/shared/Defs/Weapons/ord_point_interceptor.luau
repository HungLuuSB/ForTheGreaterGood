--!strict
-- Sanctum interceptor: a point-defence interceptor (S-149, the user). It engages enemy
-- missiles and rockets flying near its unit, never units: one interceptor
-- per missile, and a burst destroys it with `intercepts.chance`. Its stock
-- refills one at a time; a big salvo empties it. Placeholder numbers.
return {
	id = "ord_point_interceptor",
	type = "HOMING",
	range = 450, -- the cover radius
	reload = 0.3, -- between interceptors
	projectileSpeed = 600,
	accuracy = 1,
	turnRate = 720,
	launch = "vertical",
	climbHeight = 14,
	stockpile = { capacity = 8, buildTime = 2, cost = { supply = 6, power = 80 } },
	guidance = "RADAR", -- (steers at the missile; units are never its targets)
	lockRange = 450,
	intercepts = { chance = 0.85, tactical = true },
	interceptOnly = true,
	terminalRange = 30,
	damage = { LIGHT = 0, ARMORED = 0, STRUCTURE = 0, SHIP = 0, AIR = 0, SUB = 0 },
	aoe = 8,
	edgeEffectiveness = 0.5,
	targets = { "AIR" }, -- (never used: interceptOnly)
	fx = { muzzle = "missile_launch_small", trail = "smoke_thin", impact = "explosion_air_small", sound = "sam_ir" },
}
