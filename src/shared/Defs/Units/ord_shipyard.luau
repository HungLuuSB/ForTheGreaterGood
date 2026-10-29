--!strict
local Templates = require("../Templates")

-- Placeholder (guide 9.2 "Shipyard", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_shipyard",
	name = "Shipyard",
	description = "T1 naval factory. Builds the naval worker, T1 ships and submarines.",
	faction = "order",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 700, power = 2000, buildTime = 9000 },
	health = 3200,
	footprint = 5,
	icon = "factory_naval",
	placement = "water",
	buildPower = 200, -- doubled: T1 units in about half the time (S-94, client request 42b)
	buildOptions = { "ord_tidewright", "ord_sentry", "ord_silence" },
	model = "ord_shipyard",
})
