--!strict
local Templates = require("../Templates")

-- Placeholder (guide 9.2 "Shipyard", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_shipyard",
	name = "Drydock",
	description = "T1 factory: naval worker, T1 ships and submarines.",
	faction = "chaos",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 700, power = 2000, buildTime = 9000 },
	health = 3200,
	footprint = 5,
	icon = "factory_naval",
	placement = "water",
	buildPower = 200, -- doubled: T1 units in about half the time (S-94, client request 42b)
	buildOptions = { "chs_wrecker", "chs_barracuda", "chs_lamprey" },
	model = "chs_shipyard",
})
