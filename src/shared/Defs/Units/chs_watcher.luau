--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.2 "Mobile radar"); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_watcher",
	tier = 1,
	domain = "ground",
	footprint = 1,
	pieces = { "base", "dish" },
	name = "Watcher",
	description = "Mobile radar. Wide but imprecise radar coverage; unarmed.",
	faction = "chaos",
	categories = { "GROUND", "LIGHT", "RADAR_EMITTER" },
	armorClass = "LIGHT",
	moveClass = "WHEELED",
	cost = { supply = 80, power = 1000, buildTime = 2400 },
	health = 420,
	movement = { maxSpeed = 38, accel = 15, brake = 30, turnRate = 130 },
	sensors = { sight = 110, radar = 600 },
	model = "chs_watcher",
	icon = "radar",
})
