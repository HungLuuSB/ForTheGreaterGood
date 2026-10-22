--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5 "Jammer tower", T2); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_veilspire",
	name = "Veilspire",
	description = "Advanced jammer tower.",
	faction = "order",
	tier = 2,
	categories = { "STRUCTURE", "JAMMER" },
	cost = { supply = 260, power = 4200, buildTime = 6800 },
	health = 1400,
	footprint = 2, -- size shows tech level (S-104)
	sensors = { sight = 140, jam = 400, jamDrain = 30 },
	icon = "jammer",
	model = "ord_veilspire",
})
