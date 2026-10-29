--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5 "Long-range radar", T2); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_allseer",
	name = "All-Seer",
	description = "Long-range radar. Spots enemy units far beyond sight.",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE", "RADAR_EMITTER" },
	cost = { supply = 255, power = 4250, buildTime = 6800 },
	health = 1280, -- faction pass (S-62)
	footprint = 3,
	sensors = { sight = 270, radar = 950, radarError = 45, radarDrain = 9 }, -- upkeep: S-72; sight +50% (S-203, the user's H9; was 180)
	icon = "radar",
	model = "chs_allseer",
})
