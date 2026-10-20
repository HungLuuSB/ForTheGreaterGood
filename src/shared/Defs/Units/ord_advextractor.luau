--!strict
local Templates = require("../Templates")

-- Placeholder (guide 8.5 "Advanced Extractor", T2); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_advextractor",
	name = "Advanced Extractor",
	description = "Advanced Extractor. ~3.5x extractor output on a deposit.",
	faction = "order",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 300, power = 4000, buildTime = 7000 },
	health = 1200,
	footprint = 1,
	icon = "extractor",
	extractor = { rate = 1.75 },
	model = "ord_advextractor",
})
