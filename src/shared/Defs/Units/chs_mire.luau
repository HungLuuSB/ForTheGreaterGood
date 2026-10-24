--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.2 "Amphibious tank", T2); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_mire",
	name = "Mire",
	description = "Amphibious tank. Drives along the sea floor and up the beach.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	moveClass = "AMPHIB",
	footprint = 1,
	cost = { supply = 220, power = 2400, buildTime = 6200 },
	health = 1850, -- tier rebalance (S-157, the user): was 1550
	movement = { maxSpeed = 30, accel = 12, brake = 24, turnRate = 100 },
	sensors = { sight = 190 },
	weapons = { { def = "chs_light_cannon", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "tank_amphib",
	model = "chs_mire",
})
