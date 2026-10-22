--!strict
-- Custodian interceptor: an anti-nuke interceptor (S-111, the user via the client and
-- models streams). It engages enemy strategic missiles only, never units;
-- one interceptor per missile, and a burst always destroys it.
return {
	id = "ord_mobile_interceptor",
	type = "HOMING",
	range = 660, -- the coverage radius
	reload = 18, -- the delay after each shot: several nukes at one spot can overwhelm it (client request 46)
	projectileSpeed = 700,
	accuracy = 1,
	turnRate = 160,
	launch = "vertical",
	climbHeight = 40,
	stockpile = { capacity = 1, buildTime = 90, cost = { supply = 400, power = 10000 } },
	guidance = "RADAR", -- (steers at the missile; units are never its targets)
	lockRange = 660,
	intercepts = { chance = 1 },
	interceptOnly = true,
	stationary = true, -- fires only while its unit stands still: the launcher has to raise (S-111)
	terminalRange = 60,
	damage = { LIGHT = 0, ARMORED = 0, STRUCTURE = 0, SHIP = 0, AIR = 0, SUB = 0 },
	aoe = 30,
	edgeEffectiveness = 0.5,
	targets = { "AIR" }, -- (never used: interceptOnly)
	fx = { muzzle = "missile_launch_large", trail = "smoke_thick", impact = "explosion_air_large", sound = "sam_radar" },
}
