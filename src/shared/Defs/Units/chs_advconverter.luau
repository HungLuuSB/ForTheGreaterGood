--!strict
local Templates = require("../Templates")

-- H28: the T2 energy converter (S-209, the user's playtest 3; BAR's armmmkr / cormmkr).
return Templates.extend(Templates.Structure, {
	id = "chs_advconverter",
	name = "Great Smelter",
	description = "T2 converter. Turns 600 spare power a second into 10.3 supply (switch off with TOGGLE).",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 300, power = 6000, buildTime = 9000 },
	health = 1400,
	footprint = 3, -- size shows tech level (S-104)
	converter = { power = 600, supply = 10.3 }, -- (H28)
	icon = "converter",
	model = "chs_advconverter",
})
