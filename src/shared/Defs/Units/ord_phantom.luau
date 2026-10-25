--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.3 "Strategic bomber", T2); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "ord_phantom",
	name = "Phantom",
	description = "Strategic bomber. Very stealthy (0.2).",
	faction = "order",
	tier = 2,
	domain = "air",
	categories = { "AIR", "JET", "STEALTH" },
	armorClass = "AIR",
	moveClass = "JET",
	footprint = 1,
	cost = { supply = 500, power = 9000, buildTime = 15000 },
	health = 1500,
	movement = { maxSpeed = 220, minSpeed = 130, accel = 80, brake = 60, turnRate = 60 },
	sensors = { sight = 200, radarSignature = 0.2 },
	weapons = { { def = "ord_heavy_bomb", muzzle = "muzzle" } },
	pieces = { "base", "bay", "pylon", "muzzle" },
	icon = "bomber_heavy",
	ammo = 2,
	ammoCost = { supply = 40, power = 300 },
	rearmTime = 4,
	model = "ord_phantom",
})
