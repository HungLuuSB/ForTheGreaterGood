--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5 "Torpedo launcher", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_fang",
	name = "Fang",
	description = "Torpedo launcher with a short sonar.",
	faction = "chaos",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 150, power = 1200, buildTime = 3000 },
	health = 1400,
	footprint = 1,
	sensors = { sight = 140, sonar = 260 },
	weapons = { { def = "chs_torpedo", turretPiece = "launcher", muzzle = "muzzle" } },
	pieces = { "base", "launcher", "turret", "muzzle" },
	icon = "torpedo",
	placement = "water",
	model = "chs_fang",
})
