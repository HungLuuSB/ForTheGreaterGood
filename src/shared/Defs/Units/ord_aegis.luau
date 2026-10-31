--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_aegis",
	name = "Aegis",
	description = "Long-range radar SAM site. Missiles against aircraft, guided by its own radar.",
	faction = "order",
	tier = 2,
	categories = { "STRUCTURE", "ANTIAIR", "RADAR_EMITTER" },
	cost = { supply = 580, power = 7600, buildTime = 16000 }, -- (S-225) ×1.8: a long-range SAM can't blanket the map cheaply
	health = 1800,
	footprint = 3,
	sensors = { sight = 150, radar = 1200, radarError = 15 },
	weapons = { { def = "ord_radar_sam", turretPiece = "launcher", muzzle = "muzzle" } },
	pieces = { "base", "launcher", "muzzle" },
	model = "ord_aegis",
	icon = "sam_radar",
})
