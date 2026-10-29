--!strict
local Templates = require("../Templates")

-- Placeholder (guide 8.5 "Supply Depot / Power Bank", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_depot",
	name = "Depot",
	description = "Depot. Stores 1,000 supply and 1,000 power.",
	faction = "order",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 80, power = 400, buildTime = 1500 },
	health = 800,
	footprint = 2, -- size shows tech level (S-104)
	icon = "storage",
	storage = { supply = 1000, power = 1000 },
	model = "ord_depot",
})
