--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.3 "Support aircraft", T2); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "ord_archangel",
	name = "Archangel",
	description = "AWACS. Long-range airborne radar; unarmed.",
	faction = "order",
	tier = 2,
	domain = "air",
	categories = { "AIR", "JET", "RADAR_EMITTER" },
	armorClass = "AIR",
	moveClass = "JET",
	footprint = 1,
	cost = { supply = 320, power = 6000, buildTime = 10000 },
	health = 900,
	movement = { maxSpeed = 200, minSpeed = 120, accel = 80, brake = 60, turnRate = 40 },
	sensors = { sight = 220, airSight = 420, radar = 1000, radarError = 15, radarDrain = 8 }, -- upkeep: S-72
	pieces = { "base", "dish" },
	icon = "awacs",
	model = "ord_archangel",
})
