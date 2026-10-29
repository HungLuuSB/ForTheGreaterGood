--!strict
local Templates = require("../Templates")

-- Placeholder (guide 9.2 "Airfield", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_airfield",
	name = "Airfield",
	description = "T1 air factory. Builds the air worker and T1 aircraft.",
	faction = "order",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 700, power = 2400, buildTime = 9000 },
	health = 2800,
	footprint = 5,
	icon = "factory_air",
	buildPower = 200, -- doubled: T1 units in about half the time (S-94, client request 42b)
	rearmPads = 1,
	buildOptions = { "ord_skywright", "ord_falcon", "ord_guardian", "ord_absolution" },
	model = "ord_airfield",
})
