--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.2 "Mobile radar"); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "ord_oracle",
	tier = 1,
	domain = "ground",
	footprint = 1,
	pieces = { "base", "dish" },
	name = "Oracle",
	description = "Mobile radar. Long-range, precise radar coverage; unarmed.",
	faction = "order",
	categories = { "GROUND", "LIGHT", "RADAR_EMITTER" },
	armorClass = "LIGHT",
	moveClass = "WHEELED",
	cost = { supply = 105, power = 1350, buildTime = 3000 },
	health = 440, -- faction pass (S-62)
	movement = { maxSpeed = 40, accel = 16, brake = 32, turnRate = 140 },
	sensors = { sight = 120, radar = 760, radarError = 16, radarDrain = 3 }, -- upkeep: S-72
	model = "ord_oracle",
	icon = "radar",
})
