--!strict
-- S-179, the playtest's balance notes: T1 radar / jammer range halved
local Templates = require("../Templates")

-- Placeholder (guide 13.5 "Radar tower", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_watchtower",
	name = "Watchtower",
	description = "Radar tower.",
	faction = "order",
	tier = 1,
	categories = { "STRUCTURE", "RADAR_EMITTER" },
	cost = { supply = 70, power = 1000, buildTime = 2000 },
	health = 690, -- faction pass (S-62)
	footprint = 1,
	sensors = { sight = 160, radar = 350, radarError = 16, radarDrain = 3 }, -- upkeep: S-72
	icon = "radar",
	model = "ord_watchtower",
})
