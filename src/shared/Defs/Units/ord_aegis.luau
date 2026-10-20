--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_aegis",
	name = "Aegis",
	description = "Long-range radar SAM site. Own radar; can be jammed.",
	faction = "order",
	tier = 2,
	categories = { "STRUCTURE", "ANTIAIR", "RADAR_EMITTER" },
	cost = { supply = 320, power = 4200, buildTime = 9000 },
	health = 1800,
	footprint = 3,
	sensors = { sight = 150, radar = 650, radarError = 20 },
	weapons = { { def = "ord_radar_sam", turretPiece = "launcher", muzzle = "muzzle" } },
	pieces = { "base", "launcher", "muzzle" },
	model = "ord_aegis",
	icon = "sam_radar",
})
