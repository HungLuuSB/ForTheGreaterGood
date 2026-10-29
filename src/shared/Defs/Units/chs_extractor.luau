--!strict
local Templates = require("../Templates")

return Templates.extend(Templates.Structure, {
	footprint = 2, -- size shows tech level (S-104)
	id = "chs_extractor",
	name = "Excavator",
	description = "Supply extractor. Stands on a supply deposit; its income follows the deposit's value.",
	faction = "chaos",
	cost = { supply = 50, power = 500, buildTime = 1800 },
	health = 450,
	extractor = { rate = 0.5, upkeep = 3 }, -- upkeep: power it costs to run (S-198)
	model = "chs_extractor",
	icon = "extractor",
})
