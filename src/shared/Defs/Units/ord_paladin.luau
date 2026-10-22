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
	footprint = 2, -- size shows tech level (S-104)
	cost = { supply = 360, power = 3600, buildTime = 9000 },
	health = 3200, -- faction pass (S-62)
	movement = { maxSpeed = 28, accel = 10, brake = 20, turnRate = 80 },
	sensors = { sight = 230 },
	weapons = { { def = "ord_heavy_cannon", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "tank_heavy",
	model = "ord_paladin",
})
