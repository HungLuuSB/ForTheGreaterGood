--!strict
local Templates = require("../Templates")

-- Order anti-nuke (S-111): an armored launch bunker. Stockpiles
-- interceptors and shoots enemy strategic missiles in its coverage, one
-- interceptor each; never units. Placeholder numbers.
return Templates.extend(Templates.Structure, {
	id = "ord_providence",
	name = "Providence",
	description = "Anti-nuke. Stockpiles interceptors and shoots down enemy nukes over its coverage; never fires at units.",
	faction = "order",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 900, power = 14000, buildTime = 20000 },
	health = 4000,
	footprint = 3, -- size shows tech level (S-104)
	sensors = { sight = 160 }, -- no radar needed: it spots strategic missiles anywhere (the user, S-111)
	weapons = { { def = "ord_interceptor", muzzle = "muzzle" } },
	pieces = { "base", "hatch", "muzzle" },
	icon = "antinuke",
	model = "ord_providence",
})
