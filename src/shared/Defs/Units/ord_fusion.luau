--!strict
local Templates = require("../Templates")

-- Placeholder (guide 8.5 "Fusion Reactor", T2); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_fusion",
	name = "Fusion Reactor",
	description = "Fusion reactor. Makes a large amount of power.",
	faction = "order",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 900, power = 12000, buildTime = 30000 },
	health = 3000,
	footprint = 4, -- size shows tech level (S-104)
	icon = "fusion",
	production = { power = 250 },
	deathBlast = { damage = 2500, aoe = 120, edge = 0.25 }, -- guide 8.5: "big explosion on death" (S-70)
	storage = { power = 2000 },
	model = "ord_fusion",
})
