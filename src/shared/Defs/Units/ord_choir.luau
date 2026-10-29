--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5 "Sonar station", T2); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_choir",
	name = "Choir",
	description = "Sonar station. Detects ships and submarines over a wide area.",
	faction = "order",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 220, power = 3600, buildTime = 6000 },
	health = 1200,
	footprint = 3,
	sensors = { sight = 120, sonar = 720 },
	icon = "sonar",
	placement = "water",
	model = "ord_choir",
})
