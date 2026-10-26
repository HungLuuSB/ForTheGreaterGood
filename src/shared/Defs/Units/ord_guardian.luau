--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.3); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "ord_guardian",
	name = "Guardian",
	description = "Attack helicopter. Hovers and rockets ground targets.",
	faction = "order",
	tier = 1,
	domain = "air",
	categories = { "AIR", "HELI" },
	armorClass = "AIR",
	moveClass = "HELI",
	footprint = 1,
	cost = { supply = 150, power = 2400, buildTime = 5000 },
	health = 640,
	movement = { maxSpeed = 70, accel = 30, brake = 40, turnRate = 180 },
	sensors = { sight = 200, airSight = 260 },
	weapons = { { def = "ord_rockets", turretPiece = "pylon", muzzle = "muzzle" } },
	ammo = 12,
	ammoCost = { supply = 6, power = 60 },
	rearmTime = 0.6,
	countermeasures = { dircm = { chance = 0.7, cooldown = 3, powerDrain = 15 } },
	pieces = { "base", "pylon", "muzzle" },
	model = "ord_guardian",
	icon = "heli",
})
