--!strict
-- Bot Pit: the T1 bot factory (S-181, the playtest's new units).
local Templates = require("../Templates")

return Templates.extend(Templates.Structure, {
	id = "chs_botlab",
	name = "Bot Pit",
	description = "T1 factory: bots. Bots climb steep slopes, are quick and turn on the spot.",
	faction = "chaos",
	cost = { supply = 500, power = 1000, buildTime = 6000 },
	health = 2600,
	footprint = 4,
	buildPower = 200,
	buildOptions = { "chs_tinker", "chs_skitter", "chs_thug", "chs_graverobber", "chs_needle" },
	icon = "factory",
	model = "chs_botlab",
})
