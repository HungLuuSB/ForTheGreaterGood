--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5 "Artillery emplacement", T2); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_edict",
	name = "Edict",
	description = "Artillery emplacement. Very long range; can shell radar contacts.",
	faction = "order",
	tier = 2,
	categories = { "STRUCTURE", "ARTILLERY" },
	cost = { supply = 600, power = 6000, buildTime = 12000 },
	health = 4000,
	footprint = 3,
	sensors = { sight = 160 },
	weapons = { { def = "ord_howitzer", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "artillery",
	model = "ord_edict",
})
