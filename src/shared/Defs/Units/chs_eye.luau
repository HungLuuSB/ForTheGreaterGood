--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5 "Radar tower", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_eye",
	name = "Eye",
	description = "Radar tower.",
	faction = "chaos",
	tier = 1,
	categories = { "STRUCTURE", "RADAR_EMITTER" },
	cost = { supply = 60, power = 900, buildTime = 1800 },
	health = 600,
	footprint = 1,
	sensors = { sight = 160, radar = 600, radarError = 45 },
	icon = "radar",
	model = "chs_eye",
})
