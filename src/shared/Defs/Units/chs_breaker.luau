--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5 "Coastal battery", T2); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_breaker",
	name = "Breaker",
	description = "Coastal battery. Heavy gun against ships.",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 600, power = 5000, buildTime = 11000 },
	health = 5500,
	footprint = 3,
	height = 23.8, -- a tall tower (S-184; models-C's F18 blockouts, measured)
	muzzleHeight = 20.0,
	sensors = { sight = 300 },
	weapons = { { def = "chs_heavy_naval_gun", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "battery",
	model = "chs_breaker",
})
