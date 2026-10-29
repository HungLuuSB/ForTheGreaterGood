--!strict
local Templates = require("../Templates")

-- H28b: T2 hardened supply storage (S-209, the user's playtest 3; BAR's armuwadvms / coruwadvms).
return Templates.extend(Templates.Structure, {
	id = "chs_advdepot",
	name = "Great Hoard",
	description = "Hardened supply storage. +10,000 supply storage.",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 350, power = 3000, buildTime = 8000 },
	health = 4000,
	footprint = 3, -- size shows tech level (S-104)
	storage = { supply = 10000 }, -- (H28b)
	icon = "storage",
	model = "chs_advdepot",
})
