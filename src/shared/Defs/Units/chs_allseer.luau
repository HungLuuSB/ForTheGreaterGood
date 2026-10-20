--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5 "Long-range radar", T2); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_allseer",
	name = "All-Seer",
	description = "Long-range radar.",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE", "RADAR_EMITTER" },
	cost = { supply = 300, power = 5000, buildTime = 8000 },
	health = 1500,
	footprint = 3,
	sensors = { sight = 180, radar = 1000, radarError = 40 },
	icon = "radar",
	model = "chs_allseer",
})
