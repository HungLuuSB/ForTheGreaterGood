--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_thorn",
	name = "Thorn",
	description = "IR SAM site. Ignores jamming.",
	faction = "chaos",
	tier = 1,
	categories = { "STRUCTURE", "ANTIAIR" },
	cost = { supply = 90, power = 900, buildTime = 2300 },
	health = 900, -- faction pass (S-62)
	footprint = 1,
	sensors = { sight = 150, airSight = 165 }, -- airSight follows the missile's range (client request 16)
	weapons = { { def = "chs_ir_sam", turretPiece = "launcher", muzzle = "muzzle" } },
	pieces = { "base", "launcher", "muzzle" },
	model = "chs_thorn",
	icon = "sam_ir",
})
