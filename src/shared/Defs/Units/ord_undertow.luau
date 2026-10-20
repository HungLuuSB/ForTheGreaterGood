--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5 "Torpedo launcher", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_undertow",
	name = "Undertow",
	description = "Torpedo launcher with a short sonar.",
	faction = "order",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 150, power = 1200, buildTime = 3000 },
	health = 1400,
	footprint = 1,
	sensors = { sight = 140, sonar = 260 },
	weapons = { { def = "ord_torpedo", turretPiece = "launcher", muzzle = "muzzle" } },
	pieces = { "base", "launcher", "turret", "muzzle" },
	icon = "torpedo",
	placement = "water",
	model = "ord_undertow",
})
