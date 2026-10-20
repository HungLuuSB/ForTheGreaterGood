--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.2 "Main battle tank", T2); stats to balance in M8.
return Templates.extend(Templates.TankT1, {
	id = "ord_paladin",
	name = "Paladin",
	description = "Main battle tank. Heavy armor, heavy gun.",
	faction = "order",
	tier = 2,
	domain = "ground",
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	moveClass = "HEAVY_TRACKED",
	footprint = 1,
	cost = { supply = 320, power = 3200, buildTime = 8000 },
	health = 2600,
	movement = { maxSpeed = 28, accel = 10, brake = 20, turnRate = 80 },
	sensors = { sight = 230 },
	weapons = { { def = "ord_heavy_cannon", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "tank_heavy",
	model = "ord_paladin",
})
