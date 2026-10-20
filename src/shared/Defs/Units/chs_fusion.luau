--!strict
local Templates = require("../Templates")

-- Placeholder (guide 8.5 "Fusion Reactor", T2); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_fusion",
	name = "Hellforge",
	description = "Fusion Reactor. Large power.",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 900, power = 12000, buildTime = 30000 },
	health = 3000,
	footprint = 3,
	icon = "fusion",
	production = { power = 250 },
	storage = { power = 2000 },
	model = "chs_fusion",
})
