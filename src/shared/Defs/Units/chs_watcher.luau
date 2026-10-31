--!strict
-- S-179, the playtest's balance notes: T1 radar / jammer range halved
local Templates = require("../Templates")

-- Placeholder (guide 13.2 "Mobile radar"); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_watcher",
	tier = 1,
	domain = "ground",
	footprint = 1,
	pieces = { "base", "dish" },
	name = "Gazer", -- Watcher until S-225: BAR's Watcher is a different unit
	description = "Mobile radar. Spots enemy units beyond sight; unarmed.",
	faction = "chaos",
	categories = { "GROUND", "LIGHT", "RADAR_EMITTER" },
	armorClass = "LIGHT",
	moveClass = "WHEELED",
	cost = { supply = 70, power = 850, buildTime = 2100 },
	health = 360, -- faction pass (S-62)
	movement = { maxSpeed = 22.8, accel = 15, brake = 30, turnRate = 130 },
	sensors = { sight = 110, radar = 280, radarError = 50, radarDrain = 2 }, -- upkeep: S-72
	model = "chs_watcher",
	icon = "radar",
})
