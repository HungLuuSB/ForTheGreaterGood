--!strict
local Templates = require("../Templates")

-- Placeholder (guide 8.5 "Supply Depot / Power Bank", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_depot",
	name = "Hoard",
	description = "Depot. +1,000 supply and power storage.",
	faction = "chaos",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 80, power = 400, buildTime = 1500 },
	health = 800,
	footprint = 2, -- size shows tech level (S-104)
	icon = "storage",
	storage = { supply = 1000, power = 1000 },
	model = "chs_depot",
})
