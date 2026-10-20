--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5 "Gun turret", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_bulwark",
	name = "Bulwark",
	description = "Gun turret.",
	faction = "order",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 120, power = 900, buildTime = 2400 },
	health = 1800,
	footprint = 1,
	sensors = { sight = 230 },
	weapons = { { def = "ord_light_cannon", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "turret",
	model = "ord_bulwark",
})
