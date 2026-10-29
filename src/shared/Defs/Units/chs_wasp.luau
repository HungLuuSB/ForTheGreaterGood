--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.3); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_wasp",
	name = "Wasp",
	description = "Attack helicopter. Fires heavy rockets at ground targets.",
	faction = "chaos",
	tier = 1,
	domain = "air",
	categories = { "AIR", "HELI" },
	armorClass = "AIR",
	moveClass = "HELI",
	footprint = 1,
	cost = { supply = 140, power = 2200, buildTime = 4800 },
	health = 600,
	movement = { maxSpeed = 48, accel = 34, brake = 44, turnRate = 195 },
	sensors = { sight = 190, airSight = 250 },
	weapons = { { def = "chs_rockets", turretPiece = "pylon", muzzle = "muzzle" } },
	rearmTime = 0.6,
	countermeasures = { flares = { charges = 4, chance = 0.55, refillSupply = 2 } },
	pieces = { "base", "pylon", "muzzle" },
	model = "chs_wasp",
	icon = "heli",
})
