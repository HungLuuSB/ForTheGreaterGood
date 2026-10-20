--!strict
local Templates = require("../Templates")

return Templates.extend(Templates.Structure, {
	id = "chs_extractor",
	name = "Excavator",
	description = "Supply Extractor. Must stand on a supply deposit; income scales with its value.",
	faction = "chaos",
	cost = { supply = 50, power = 500, buildTime = 1800 },
	health = 450,
	extractor = { rate = 0.5 },
	model = "chs_extractor",
	icon = "extractor",
})
