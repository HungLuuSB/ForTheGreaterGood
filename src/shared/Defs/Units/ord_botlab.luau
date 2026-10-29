--!strict
-- Bot Lab: the T1 bot factory (S-181, the playtest's new units).
local Templates = require("../Templates")

return Templates.extend(Templates.Structure, {
	id = "ord_botlab",
	name = "Bot Lab",
	description = "T1 bot factory. Builds bots, which climb steep slopes and turn on the spot.",
	faction = "order",
	cost = { supply = 550, power = 1100, buildTime = 6500 },
	health = 2800,
	footprint = 4,
	buildPower = 200,
	buildOptions = { "ord_artisan", "ord_glint", "ord_mace", "ord_lazarus", "ord_kestrel" },
	icon = "factory",
	model = "ord_botlab",
})
