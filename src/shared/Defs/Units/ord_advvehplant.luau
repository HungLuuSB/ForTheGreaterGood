--!strict
local Templates = require("../Templates")

-- Placeholder (guide 9.2 "Advanced Vehicle Plant", T2); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_advvehplant",
	name = "Advanced Vehicle Plant",
	description = "T2 vehicle factory. Builds the advanced ground worker and T2 ground units.",
	faction = "order",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 2200, power = 9000, buildTime = 30000 },
	health = 6000,
	footprint = 6, -- size shows tech level (S-104)
	icon = "factory",
	buildPower = 200,
	buildOptions = { "ord_architect", "ord_paladin", "ord_judgement", "ord_seraph", "ord_veil", "ord_tideguard", "ord_arbiter", "ord_warden", "ord_custodian", "ord_shepherd" },
	model = "ord_advvehplant",
})
