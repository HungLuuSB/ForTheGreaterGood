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
	cost = { supply = 100, power = 1000, buildTime = 2600 },
	health = 1000,
	footprint = 1,
	sensors = { sight = 150, airSight = 206 }, -- airSight follows the missile's range (client request 16)
	weapons = { { def = "chs_ir_sam", turretPiece = "launcher", muzzle = "muzzle" } },
	pieces = { "base", "launcher", "muzzle" },
	model = "chs_thorn",
	icon = "sam_ir",
})
