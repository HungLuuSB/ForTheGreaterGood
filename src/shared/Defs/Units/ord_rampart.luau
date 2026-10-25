--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5 "Coastal battery", T2); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_rampart",
	name = "Rampart",
	description = "Coastal battery. Heavy gun against ships.",
	faction = "order",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 600, power = 5000, buildTime = 11000 },
	health = 5000,
	footprint = 3,
	height = 23, -- a tall tower (S-184; models-C's F18 blockouts)
	muzzleHeight = 16,
	sensors = { sight = 300 },
	weapons = { { def = "ord_heavy_naval_gun", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "battery",
	model = "ord_rampart",
})
