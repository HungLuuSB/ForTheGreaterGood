--!strict
local Templates = require("../Templates")

-- Placeholder (guide 8.5 "Wind Turbine", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_windmill",
	name = "Wind Turbine",
	faction = "order",
	tier = 1,
	categories = { "STRUCTURE" },
	footprint = 1,
	description = "Wind Turbine. Power that follows the wind (0-30 per second, changes every 30 s).",
	cost = { supply = 35, power = 0, buildTime = 1000 },
	health = 220,
	wind = { max = 30 },
	icon = "wind",
	model = "ord_windmill",
})
