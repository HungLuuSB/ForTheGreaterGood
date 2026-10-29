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
	description = "Wind turbine. Makes power that rises and falls with the map's wind, up to 30 a second.",
	cost = { supply = 40, power = 175, buildTime = 1000 }, -- (S-203, the user's H24; was 35 / 0)
	health = 220,
	wind = { max = 30 },
	icon = "wind",
	model = "ord_windmill",
})
