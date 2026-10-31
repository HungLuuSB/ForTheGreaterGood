--!strict
local Templates = require("../Templates")

return Templates.extend(Templates.Structure, {
	id = "chs_vehplant",
	name = "Vehicle Foundry",
	description = "T1 vehicle factory. Builds the ground worker and T1 ground units.",
	faction = "chaos",
	cost = { supply = 580, power = 1100, buildTime = 6800 },
	health = 3300,
	footprint = 4, -- size shows tech level (S-104)
	buildPower = 200, -- doubled: T1 units in about half the time (S-94, client request 42b)
	buildOptions = { "chs_scrapper", "chs_jackal", "chs_ravager", "chs_hellmouth", "chs_hornet", "chs_watcher", "chs_locust", "chs_cleaver", "chs_mudskipper", "chs_dredger" },
	model = "chs_vehplant",
	icon = "factory",
})
