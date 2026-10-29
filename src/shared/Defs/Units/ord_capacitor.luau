--!strict
local Templates = require("../Templates")

-- H27: T1 energy storage (S-209, the user's playtest 3; BAR's armestor).
return Templates.extend(Templates.Structure, {
	id = "ord_capacitor",
	name = "Capacitor Bank",
	description = "Energy storage. +6,000 power storage.",
	faction = "order",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 100, power = 700, buildTime = 2000 },
	health = 900,
	footprint = 2, -- size shows tech level (S-104)
	storage = { power = 6000 }, -- (H27)
	icon = "storage",
	model = "ord_capacitor",
})
