--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.3 "Support aircraft", T2); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_banshee",
	name = "Banshee",
	description = "EW jammer aircraft. Hides friendly units from radar over a wide area.",
	faction = "chaos",
	tier = 2,
	domain = "air",
	categories = { "AIR", "JET", "JAMMER" },
	armorClass = "AIR",
	moveClass = "JET",
	footprint = 1,
	cost = { supply = 320, power = 6000, buildTime = 10000 },
	health = 900,
	movement = { maxSpeed = 200, minSpeed = 120, accel = 80, brake = 60, turnRate = 60 },
	sensors = { sight = 200, jam = 480, jamDrain = 25 },
	pieces = { "base", "dish" },
	icon = "ew_aircraft",
	model = "chs_banshee",
})
