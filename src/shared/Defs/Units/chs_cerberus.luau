--!strict
local Templates = require("../Templates")

-- Chaos anti-nuke (S-111): an open launcher on a reinforced pad.
-- Stockpiles interceptors and shoots enemy strategic missiles in its
-- coverage, one interceptor each; never units. Placeholder numbers.
return Templates.extend(Templates.Structure, {
	id = "chs_cerberus",
	name = "Cerberus",
	description = "Anti-nuke. Stockpiles interceptors; shoots down enemy nukes over its coverage. Never fires at units.",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 780, power = 12000, buildTime = 18000 },
	health = 3400,
	footprint = 3, -- size shows tech level (S-104)
	sensors = { sight = 160 }, -- no radar needed: it spots strategic missiles anywhere (the user, S-111)
	weapons = { { def = "chs_interceptor", muzzle = "muzzle" } },
	pieces = { "base", "launcher", "muzzle" },
	icon = "antinuke",
	model = "chs_cerberus",
})
