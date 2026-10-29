--!strict
local Templates = require("../Templates")

-- H29: T2 hardened power storage (S-209, the user's playtest 3; BAR's coruwadves).
return Templates.extend(Templates.Structure, {
	id = "chs_advaccumulator",
	name = "Great Accumulator",
	description = "Advanced energy storage. Stores 60,000 power.",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 400, power = 4500, buildTime = 9000 },
	health = 4000,
	footprint = 3, -- size shows tech level (S-104)
	storage = { power = 60000 }, -- (H29)
	icon = "storage",
	model = "chs_advaccumulator",
})
