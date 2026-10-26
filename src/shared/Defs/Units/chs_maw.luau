--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5 "Heavy turret", T2); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_maw",
	name = "Maw",
	description = "Heavy turret.",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 380, power = 3800, buildTime = 7600 },
	health = 5800,
	footprint = 3, -- size shows tech level (S-104)
	height = 23.6, -- a tall tower (S-184; models-C's F18 blockouts, measured)
	muzzleHeight = 18.6,
	sensors = { sight = 240 },
	weapons = { { def = "chs_heavy_cannon", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "turret_heavy",
	model = "chs_maw",
})
