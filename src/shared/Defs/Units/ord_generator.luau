--!strict
local Templates = require("../Templates")

return Templates.extend(Templates.Structure, {
	id = "ord_generator",
	name = "Generator",
	description = "Power Generator. Steady power.",
	faction = "order",
	cost = { supply = 40, power = 0, buildTime = 1200 },
	health = 300,
	production = { power = 20 },
	storage = { power = 100 },
	model = "ord_generator",
	icon = "generator",
})
