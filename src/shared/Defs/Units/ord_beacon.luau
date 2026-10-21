--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5 "Long-range radar", T2); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_beacon",
	name = "Beacon",
	description = "Long-range radar.",
	faction = "order",
	tier = 2,
	categories = { "STRUCTURE", "RADAR_EMITTER" },
	cost = { supply = 345, power = 5750, buildTime = 9200 },
	health = 1720, -- faction pass (S-62)
	footprint = 3,
	sensors = { sight = 180, radar = 1250, radarError = 12, radarDrain = 12 }, -- upkeep: S-72
	icon = "radar",
	model = "ord_beacon",
})
