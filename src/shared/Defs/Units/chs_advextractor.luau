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
	footprint = 2, -- the T1's size: an upgraded T1 on the same 2 × 2 patch (the user, S-184; not S-104's size-by-tier rule)
	icon = "extractor",
	extractor = { rate = 1.75, upkeep = 15 }, -- upkeep: power it costs to run (S-198)
	upgradesFrom = { "chs_extractor" }, -- built over its own T1 extractor, which works on until this finishes (S-108)
	model = "chs_advextractor",
})
