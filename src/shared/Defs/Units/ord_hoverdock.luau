--!strict
-- Hover Dock: the Order hovercraft factory (S-230, the BAR roster program's
-- batch 1; BAR's armhp + armfhp, merged into one def that stands on land or
-- water, placement "either").
local Templates = require("../Templates")

return Templates.extend(Templates.Structure, {
	id = "ord_hoverdock",
	name = "Hover Dock",
	description = "Hovercraft factory. Stands on land or water; builds the hover worker and hovercraft.",
	faction = "order",
	cost = { supply = 460, power = 1100, buildTime = 7000 },
	health = 3100,
	footprint = 4, -- (C's blockout: a 22-stud deck, like the vehicle plants)
	placement = "either",
	buildPower = 200,
	buildOptions = { "ord_skimwright", "ord_skimmer", "ord_volley", "ord_dart", "ord_halcyon" },
	pieces = { "base", "buildpad", "nano1", "nano2", "nano3" },
	model = "ord_hoverdock",
	icon = "factory",
})
