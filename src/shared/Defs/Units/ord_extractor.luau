--!strict
local Templates = require("../Templates")

return Templates.extend(Templates.Structure, {
	footprint = 2, -- size shows tech level (S-104)
	id = "ord_extractor",
	name = "Extractor",
	description = "Supply Extractor. Must stand on a supply deposit; income scales with its value.",
	faction = "order",
	cost = { supply = 50, power = 500, buildTime = 1800 },
	health = 400,
	extractor = { rate = 0.5, upkeep = 3 }, -- upkeep: power it costs to run (S-198)
	model = "ord_extractor",
	icon = "extractor",
})
