--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5 "Jammer tower", T2); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_blackout",
	name = "Blackout",
	description = "Advanced jammer tower.",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE", "JAMMER" },
	cost = { supply = 260, power = 4200, buildTime = 6800 },
	health = 1400,
	footprint = 1,
	sensors = { sight = 140, jam = 550, jamDrain = 35 },
	icon = "jammer",
	model = "chs_blackout",
})
