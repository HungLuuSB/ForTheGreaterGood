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
	cost = { supply = 120, power = 1200, buildTime = 3100 },
	health = 1300, -- faction pass (S-62)
	footprint = 1,
	sensors = { sight = 160, airSight = 206 },
	weapons = { { def = "ord_ir_sam", turretPiece = "launcher", muzzle = "muzzle" } },
	pieces = { "base", "launcher", "muzzle" },
	model = "ord_vigil",
	icon = "sam_ir",
})
