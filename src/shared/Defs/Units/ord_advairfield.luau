--!strict
local Templates = require("../Templates")

-- Placeholder (guide 9.2 "Advanced Airfield", T2); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_advairfield",
	name = "Advanced Airfield",
	description = "T2 factory: advanced air worker and T2 aircraft.",
	faction = "order",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 2400, power = 12000, buildTime = 34000 },
	health = 5000,
	footprint = 6, -- size shows tech level (S-104)
	icon = "factory_air",
	buildPower = 200,
	rearmPads = 2,
	buildOptions = { "ord_zenith", "ord_archon", "ord_phantom", "ord_tidewatch", "ord_archangel" },
	model = "ord_advairfield",
})
