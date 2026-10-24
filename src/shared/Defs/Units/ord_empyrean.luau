--!strict
local Templates = require("../Templates")

-- Advanced rearm pad (guide 13.1 "advanced rearm pads", S-166): two
-- aircraft at once, each rearmed twice as fast as on an Aerie.
return Templates.extend(Templates.Structure, {
	id = "ord_empyrean",
	name = "Empyrean",
	description = "Advanced rearm pad. Rearms two aircraft at once, twice as fast.",
	faction = "order",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 300, power = 3600, buildTime = 7000 },
	health = 3000,
	footprint = 4, -- two bays
	sensors = { sight = 140 },
	rearmPads = 2,
	rearmSpeed = 2,
	model = "ord_empyrean",
	icon = "airpad",
})
