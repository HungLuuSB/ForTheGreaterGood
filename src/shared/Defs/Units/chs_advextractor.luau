--!strict
local Templates = require("../Templates")

-- Placeholder (guide 8.5 "Advanced Extractor", T2); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_advextractor",
	name = "Deep Excavator",
	description = "Advanced Extractor. ~3.5x extractor output on a deposit.",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 300, power = 4000, buildTime = 7000 },
	health = 1200,
	footprint = 4, -- size shows tech level (S-104); 4 since S-184: centred over the T1 extractor on its 2 × 2 patch
	icon = "extractor",
	extractor = { rate = 1.75 },
	upgradesFrom = { "chs_extractor" }, -- built over its own T1 extractor, which works on until this finishes (S-108)
	model = "chs_advextractor",
})
