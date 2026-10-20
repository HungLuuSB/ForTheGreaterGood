--!strict
local Templates = require("../Templates")

return Templates.extend(Templates.Structure, {
	id = "chs_vehplant",
	name = "Vehicle Foundry",
	description = "T1 factory: ground worker and T1 ground units.",
	faction = "chaos",
	cost = { supply = 580, power = 1100, buildTime = 6800 },
	health = 3300,
	footprint = 3,
	buildPower = 100,
	buildOptions = { "chs_scrapper", "chs_ravager" },
	model = "chs_vehplant",
	icon = "factory",
})
