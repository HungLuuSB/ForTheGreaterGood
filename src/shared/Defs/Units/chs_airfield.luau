--!strict
local Templates = require("../Templates")

-- Placeholder (guide 9.2 "Airfield", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_airfield",
	name = "Aerodrome",
	description = "T1 air factory. Builds the air worker and T1 aircraft.",
	faction = "chaos",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 700, power = 2400, buildTime = 9000 },
	health = 2800,
	footprint = 5,
	icon = "factory_air",
	buildPower = 200, -- doubled: T1 units in about half the time (S-94, client request 42b)
	rearmPads = 1,
	buildOptions = { "chs_vulture", "chs_harpy", "chs_wasp", "chs_plague", "chs_buzzard" },
	model = "chs_airfield",
})
