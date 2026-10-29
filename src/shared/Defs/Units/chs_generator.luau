--!strict
local Templates = require("../Templates")

return Templates.extend(Templates.Structure, {
	footprint = 2, -- size shows tech level (S-104)
	id = "chs_generator",
	name = "Furnace",
	description = "Power Generator. Steady power.",
	retired = true, -- (S-203, the user's H22) removed from both factions: the solar array makes its 20 power now; kept for old replays and scenes
	faction = "chaos",
	cost = { supply = 40, power = 0, buildTime = 1200 },
	health = 340,
	production = { power = 20 },
	storage = { power = 100 },
	model = "chs_generator",
	icon = "generator",
})
