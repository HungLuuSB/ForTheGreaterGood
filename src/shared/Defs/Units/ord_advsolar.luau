--!strict
local Templates = require("../Templates")

-- H25: four solar arrays in one (S-209, the user's playtest 3; BAR's armadvsol / coradvsol).
return Templates.extend(Templates.Structure, {
	id = "ord_advsolar",
	name = "Advanced Solar Collector",
	description = "Advanced solar collector. Makes 80 power and stores 100.",
	faction = "order",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 120, power = 1500, buildTime = 3000 },
	health = 600,
	footprint = 2, -- size shows tech level (S-104)
	production = { power = 80 }, -- (H25)
	storage = { power = 100 },
	icon = "solar",
	model = "ord_advsolar",
})
