--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.3 "Strategic bomber", T2); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "ord_phantom",
	name = "Eclipse", -- Phantom until S-225: BAR's Phantom is a different unit
	description = "Strategic bomber. A stealthy heavy bomber.",
	faction = "order",
	tier = 2,
	domain = "air",
	categories = { "AIR", "JET", "STEALTH" },
	armorClass = "AIR",
	moveClass = "JET",
	footprint = 1,
	cost = { supply = 500, power = 9000, buildTime = 15000 },
	health = 1500,
	movement = { maxSpeed = 132, minSpeed = 78, accel = 80, brake = 60, turnRate = 60 },
	sensors = { sight = 200, radarSignature = 0.2 },
	weapons = { { def = "ord_heavy_bomb", muzzle = "muzzle" } },
	pieces = { "base", "bay", "pylon", "muzzle" },
	icon = "bomber_heavy",
	rearmTime = 4,
	model = "ord_phantom",
})
