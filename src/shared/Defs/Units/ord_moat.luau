--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5 "Floating turret", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_moat",
	name = "Moat",
	description = "Floating turret.",
	faction = "order",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 140, power = 1100, buildTime = 2800 },
	-- S-179, the playtest's balance notes: health × 2
	health = 3600,
	footprint = 1,
	sensors = { sight = 240 },
	weapons = { { def = "ord_moat_gun", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "turret_naval",
	placement = "water",
	model = "ord_moat",
})
