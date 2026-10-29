--!strict
local Templates = require("../Templates")

-- Placeholder (guide 9.2 "Advanced Shipyard", T2); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_advshipyard",
	name = "Advanced Drydock",
	description = "T2 naval factory. Builds the advanced naval worker, T2 ships and the carrier.",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 2400, power = 10000, buildTime = 34000 },
	health = 6500,
	footprint = 6, -- size shows tech level (S-104)
	icon = "factory_naval",
	placement = "water",
	buildPower = 200,
	buildOptions = { "chs_reaver", "chs_corsair", "chs_kraken", "chs_leviathan", "chs_siren" },
	model = "chs_advshipyard",
})
