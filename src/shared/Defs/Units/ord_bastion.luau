--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5 "Heavy turret", T2); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_bastion",
	name = "Bastion",
	description = "Heavy turret.",
	faction = "order",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 380, power = 3800, buildTime = 7600 },
	health = 5200,
	footprint = 3, -- size shows tech level (S-104)
	sensors = { sight = 260 },
	weapons = { { def = "ord_heavy_cannon", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "turret_heavy",
	model = "ord_bastion",
})
