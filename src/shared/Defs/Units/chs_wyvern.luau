--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_wyvern",
	name = "Wyvern",
	description = "Long-range radar SAM site. Missiles against aircraft, guided by its own radar.",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE", "ANTIAIR", "RADAR_EMITTER" },
	cost = { supply = 540, power = 6800, buildTime = 15000 }, -- (S-225) ×1.8: a long-range SAM can't blanket the map cheaply
	health = 1900,
	footprint = 3,
	sensors = { sight = 140, radar = 950, radarError = 50 },
	weapons = { { def = "chs_radar_sam", turretPiece = "launcher", muzzle = "muzzle" } },
	pieces = { "base", "launcher", "muzzle" },
	model = "chs_wyvern",
	icon = "sam_radar",
})
