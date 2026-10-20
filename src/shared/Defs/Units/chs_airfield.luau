--!strict
local Templates = require("../Templates")

-- Placeholder (guide 9.2 "Airfield", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_airfield",
	name = "Aerodrome",
	description = "T1 factory: air worker and T1 aircraft.",
	faction = "chaos",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 700, power = 2400, buildTime = 9000 },
	health = 2800,
	footprint = 5,
	icon = "factory_air",
	buildPower = 100,
	rearmPads = 1,
	buildOptions = { "chs_vulture", "chs_harpy", "chs_wasp", "chs_plague" },
	model = "chs_airfield",
})
