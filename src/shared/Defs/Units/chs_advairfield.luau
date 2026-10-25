--!strict
local Templates = require("../Templates")

-- Placeholder (guide 9.2 "Advanced Airfield", T2); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_advairfield",
	name = "Advanced Aerodrome",
	description = "T2 factory: advanced air worker and T2 aircraft.",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 2400, power = 12000, buildTime = 34000 },
	health = 5000,
	footprint = 6, -- size shows tech level (S-104)
	icon = "factory_air",
	buildPower = 200,
	rearmPads = 2,
	buildOptions = { "chs_condor", "chs_manticore", "chs_behemoth", "chs_dragon", "chs_leech", "chs_banshee", "chs_wraith" },
	model = "chs_advairfield",
})
