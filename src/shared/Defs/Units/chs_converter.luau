--!strict
local Templates = require("../Templates")

-- Placeholder (guide 8.5 "Supply Converter", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_converter",
	name = "Smelter",
	faction = "chaos",
	tier = 1,
	categories = { "STRUCTURE" },
	footprint = 1,
	description = "Supply Converter. Turns spare power into supply (switch off with TOGGLE).",
	cost = { supply = 60, power = 1200, buildTime = 2200 },
	health = 400,
	converter = { power = 60, supply = 1 },
	icon = "converter",
	model = "chs_converter",
})
