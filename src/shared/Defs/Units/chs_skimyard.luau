--!strict
-- Skim Yard: the Chaos hovercraft factory (S-230, the BAR roster program's
-- batch 1; BAR's corhp + corfhp, merged into one def that stands on land or
-- water, placement "either").
local Templates = require("../Templates")

return Templates.extend(Templates.Structure, {
	id = "chs_skimyard",
	name = "Skim Yard",
	description = "Hovercraft factory. Stands on land or water; builds the hover worker and hovercraft.",
	faction = "chaos",
	cost = { supply = 460, power = 1100, buildTime = 7000 },
	health = 3500,
	footprint = 4, -- (C's blockout: a 22-stud deck, like the vehicle plants)
	placement = "either",
	buildPower = 200,
	buildOptions = { "chs_drifter", "chs_snapjaw", "chs_sling", "chs_gnat", "chs_skua", "chs_glaive" },
	pieces = { "base" },
	model = "chs_skimyard",
	icon = "factory",
})
