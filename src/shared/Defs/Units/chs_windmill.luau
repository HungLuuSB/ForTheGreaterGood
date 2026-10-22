--!strict
local Templates = require("../Templates")

-- Placeholder (guide 8.5 "Wind Turbine", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_windmill",
	name = "Wind Pylon",
	faction = "chaos",
	tier = 1,
	categories = { "STRUCTURE" },
	footprint = 2, -- size shows tech level (S-104)
	description = "Wind Turbine. Power that follows the wind (0-34 per second, changes every 30 s).",
	cost = { supply = 35, power = 0, buildTime = 1000 },
	health = 220,
	wind = { max = 34 },
	icon = "wind",
	model = "chs_windmill",
})
