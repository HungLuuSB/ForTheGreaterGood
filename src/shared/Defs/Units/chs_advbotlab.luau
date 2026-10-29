--!strict
-- Advanced Bot Pit: the T2 bot factory (S-181, the playtest's new units).
local Templates = require("../Templates")

return Templates.extend(Templates.Structure, {
	id = "chs_advbotlab",
	name = "Advanced Bot Pit",
	description = "T2 factory: heavy bots.",
	faction = "chaos",
	tier = 2,
	cost = { supply = 2000, power = 8500, buildTime = 28000 },
	health = 5500,
	footprint = 5,
	buildPower = 200,
	buildOptions = { "chs_tinker", "chs_centurion", "chs_mammoth" },
	icon = "factory",
	model = "chs_advbotlab",
})
