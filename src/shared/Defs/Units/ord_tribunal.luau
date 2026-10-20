--!strict
local Templates = require("../Templates")

-- Placeholder (guide 11.7, 13.5 "Fire-control radar"); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_tribunal",
	name = "Tribunal",
	description = "Fire-control radar. Tracks radar contacts precisely for artillery, bombers and radar SAMs; drains power.",
	faction = "order",
	tier = 2,
	categories = { "STRUCTURE", "RADAR_EMITTER" },
	cost = { supply = 220, power = 3200, buildTime = 6000 },
	health = 900,
	footprint = 2,
	sensors = { sight = 140, track = 700, trackError = 4, trackDrain = 40 },
	icon = "tracking",
	model = "ord_tribunal",
})
