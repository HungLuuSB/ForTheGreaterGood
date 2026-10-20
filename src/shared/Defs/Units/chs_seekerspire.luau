--!strict
local Templates = require("../Templates")

-- Placeholder (guide 11.7, 13.5 "Fire-control radar"); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_seekerspire",
	name = "Seeker Spire",
	description = "Fire-control radar. Cheaper and less precise than Order's; drains power.",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE", "RADAR_EMITTER" },
	cost = { supply = 150, power = 2200, buildTime = 4500 },
	health = 700,
	footprint = 2,
	sensors = { sight = 140, track = 600, trackError = 10, trackDrain = 25 },
	icon = "tracking",
	model = "chs_seekerspire",
})
