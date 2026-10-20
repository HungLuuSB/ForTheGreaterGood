--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_wyvern",
	name = "Wyvern",
	description = "Long-range radar SAM site. Own radar; can be jammed.",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE", "ANTIAIR", "RADAR_EMITTER" },
	cost = { supply = 300, power = 3800, buildTime = 8500 },
	health = 1900,
	footprint = 3,
	sensors = { sight = 140, radar = 600, radarError = 45 },
	weapons = { { def = "chs_radar_sam", turretPiece = "launcher", muzzle = "muzzle" } },
	pieces = { "base", "launcher", "muzzle" },
	model = "chs_wyvern",
	icon = "sam_radar",
})
