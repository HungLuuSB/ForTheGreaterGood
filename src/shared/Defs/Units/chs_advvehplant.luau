--!strict
local Templates = require("../Templates")

-- Placeholder (guide 9.2 "Advanced Vehicle Plant", T2); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_advvehplant",
	name = "Advanced Foundry",
	description = "T2 factory: advanced ground worker and T2 ground units.",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 2200, power = 9000, buildTime = 30000 },
	health = 6000,
	footprint = 5,
	icon = "factory",
	buildPower = 200,
	buildOptions = { "chs_forgemaster", "chs_juggernaut", "chs_hydra", "chs_gorgon", "chs_shroud", "chs_mire" },
	model = "chs_advvehplant",
})
