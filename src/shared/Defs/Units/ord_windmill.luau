--!strict
local Templates = require("../Templates")

-- Placeholder (guide 8.5 "Wind Turbine", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_windmill",
	name = "Wind Turbine",
	faction = "order",
	tier = 1,
	categories = { "STRUCTURE" },
	footprint = 2, -- size shows tech level (S-104)
	description = "Wind Turbine. Power that follows the map's wind (up to 30 per second; the wind rises and falls slowly between the map's minimum and maximum).",
	cost = { supply = 35, power = 0, buildTime = 1000 },
	health = 220,
	wind = { max = 30 },
	icon = "wind",
	model = "ord_windmill",
})
