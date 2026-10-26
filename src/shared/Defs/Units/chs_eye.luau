--!strict
-- S-179, the playtest's balance notes: T1 radar / jammer range halved
local Templates = require("../Templates")

-- Placeholder (guide 13.5 "Radar tower", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_eye",
	name = "Eye",
	description = "Radar tower.",
	faction = "chaos",
	tier = 1,
	categories = { "STRUCTURE", "RADAR_EMITTER" },
	cost = { supply = 55, power = 750, buildTime = 1600 },
	health = 510, -- faction pass (S-62)
	footprint = 1,
	sensors = { sight = 160, radar = 280, radarError = 50, radarDrain = 2 }, -- upkeep: S-72
	icon = "radar",
	model = "chs_eye",
})
