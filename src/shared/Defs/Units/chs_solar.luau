--!strict
local Templates = require("../Templates")

-- Placeholder (guide 8.5 "Solar Array", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_solar",
	name = "Sun Trap",
	description = "Solar array. Makes low, steady power.",
	faction = "chaos",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 100, power = 0, buildTime = 900 }, -- (S-217, the user) was 30 supply
	health = 250,
	footprint = 2, -- size shows tech level (S-104)
	icon = "solar",
	production = { power = 20 }, -- (S-203, the user's H23; was 8)
	storage = { power = 50 },
	model = "chs_solar",
})
