--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5 "Radar tower", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_watchtower",
	name = "Watchtower",
	description = "Radar tower.",
	faction = "order",
	tier = 1,
	categories = { "STRUCTURE", "RADAR_EMITTER" },
	cost = { supply = 60, power = 900, buildTime = 1800 },
	health = 600,
	footprint = 1,
	sensors = { sight = 160, radar = 650, radarError = 20 },
	icon = "radar",
	model = "ord_watchtower",
})
