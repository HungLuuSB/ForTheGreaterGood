--!strict
-- S-179, the playtest's balance notes: T1 radar / jammer range halved
local Templates = require("../Templates")

-- Placeholder (guide 13.5 "Jammer tower", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_smog",
	name = "Smog",
	description = "Jammer tower.",
	faction = "chaos",
	tier = 1,
	categories = { "STRUCTURE", "JAMMER" },
	cost = { supply = 90, power = 1600, buildTime = 2600 },
	health = 700,
	footprint = 1,
	sensors = { sight = 120, jam = 175, jamDrain = 18 },
	icon = "jammer",
	model = "chs_smog",
})
