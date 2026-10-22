--!strict
local Templates = require("../Templates")

-- Placeholder (guide 8.5 "Supply Converter", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_converter",
	name = "Supply Converter",
	faction = "order",
	tier = 1,
	categories = { "STRUCTURE" },
	footprint = 2, -- size shows tech level (S-104)
	description = "Supply Converter. Turns spare power into supply (switch off with TOGGLE).",
	cost = { supply = 60, power = 1200, buildTime = 2200 },
	health = 400,
	converter = { power = 70, supply = 1 },
	icon = "converter",
	model = "ord_converter",
})
