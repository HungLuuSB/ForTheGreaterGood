--!strict
local Templates = require("../Templates")

-- Placeholder (guide 9.2 "Airfield", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_airfield",
	name = "Airfield",
	description = "T1 factory: air worker and T1 aircraft.",
	faction = "order",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 700, power = 2400, buildTime = 9000 },
	health = 2800,
	footprint = 5,
	icon = "factory_air",
	buildPower = 100,
	rearmPads = 1,
	buildOptions = { "ord_skywright", "ord_falcon", "ord_guardian", "ord_absolution" },
	model = "ord_airfield",
})
