--!strict
-- Advanced Bot Lab: the T2 bot factory (S-181, the playtest's new units).
local Templates = require("../Templates")

return Templates.extend(Templates.Structure, {
	id = "ord_advbotlab",
	name = "Advanced Bot Lab",
	description = "T2 factory: heavy bots.",
	faction = "order",
	tier = 2,
	cost = { supply = 2000, power = 8500, buildTime = 28000 },
	health = 5500,
	footprint = 5,
	buildPower = 200,
	buildOptions = { "ord_artisan", "ord_fatboy" },
	icon = "factory",
	model = "ord_advbotlab",
})
