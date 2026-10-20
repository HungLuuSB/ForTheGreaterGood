--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_vigil",
	name = "Vigil",
	description = "IR SAM site. Short range; ignores jamming.",
	faction = "order",
	tier = 1,
	categories = { "STRUCTURE", "ANTIAIR" },
	cost = { supply = 110, power = 1100, buildTime = 2800 },
	health = 1100,
	footprint = 1,
	sensors = { sight = 160, airSight = 320 },
	weapons = { { def = "ord_ir_sam", turretPiece = "launcher", muzzle = "muzzle" } },
	pieces = { "base", "launcher", "muzzle" },
	model = "ord_vigil",
	icon = "sam_ir",
})
