--!strict
local Templates = require("../Templates")

-- Placeholder (guide 11.7, 13.2 "Mobile fire-control radar"); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "ord_arbiter",
	tier = 2,
	domain = "ground",
	footprint = 1,
	pieces = { "base", "dish" },
	name = "Arbiter",
	description = "Mobile fire-control radar. Tracks radar contacts for the guns; unarmed, drains power.",
	faction = "order",
	categories = { "GROUND", "LIGHT", "RADAR_EMITTER" },
	armorClass = "LIGHT",
	moveClass = "WHEELED",
	cost = { supply = 160, power = 2400, buildTime = 4800 },
	health = 420,
	movement = { maxSpeed = 36, accel = 14, brake = 30, turnRate = 120 },
	sensors = { sight = 130, track = 450, trackError = 6, trackDrain = 25 },
	model = "ord_arbiter",
	icon = "tracking",
})
