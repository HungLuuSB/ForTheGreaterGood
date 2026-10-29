--!strict
local Templates = require("../Templates")

-- Placeholder (guide 8.5 "Tidal Generator", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_tidal",
	name = "Tidal Generator",
	description = "Tidal generator. Makes steady power; built on water.",
	faction = "order",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 60, power = 0, buildTime = 1600 },
	health = 400,
	footprint = 2, -- size shows tech level (S-104)
	icon = "tidal",
	placement = "water",
	production = { power = 25 },
	model = "ord_tidal",
})
