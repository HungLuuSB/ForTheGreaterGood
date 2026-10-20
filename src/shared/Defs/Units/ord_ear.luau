--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5 "Sonar buoy", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_ear",
	name = "Ear",
	description = "Sonar buoy.",
	faction = "order",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 40, power = 600, buildTime = 1200 },
	health = 300,
	footprint = 1,
	sensors = { sight = 80, sonar = 360 },
	icon = "sonar",
	placement = "water",
	model = "ord_ear",
})
