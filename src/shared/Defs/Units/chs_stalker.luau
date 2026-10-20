--!strict
local Templates = require("../Templates")

-- Placeholder (guide 11.7, 13.2 "Mobile fire-control radar"); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_stalker",
	tier = 2,
	domain = "ground",
	footprint = 1,
	pieces = { "base", "dish" },
	name = "Stalker",
	description = "Mobile fire-control radar. Cheaper, shorter-ranged and less precise than Order's; drains power.",
	faction = "chaos",
	categories = { "GROUND", "LIGHT", "RADAR_EMITTER" },
	armorClass = "LIGHT",
	moveClass = "WHEELED",
	cost = { supply = 120, power = 1700, buildTime = 3600 },
	health = 380,
	movement = { maxSpeed = 40, accel = 16, brake = 32, turnRate = 130 },
	sensors = { sight = 130, track = 380, trackError = 12, trackDrain = 18 },
	model = "chs_stalker",
	icon = "tracking",
})
