--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.1 "Air Worker", T1); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_vulture",
	name = "Vulture",
	description = "Air worker. Builds and reclaims.",
	faction = "chaos",
	tier = 1,
	domain = "air",
	categories = { "AIR", "HELI", "WORKER" },
	armorClass = "AIR",
	moveClass = "HELI",
	footprint = 1,
	cost = { supply = 140, power = 2400, buildTime = 4200 },
	health = 420,
	movement = { maxSpeed = 70, accel = 30, brake = 40, turnRate = 140 },
	sensors = { sight = 120 },
	buildPower = 90,
	buildRange = 48,
	buildOptions = { "chs_extractor", "chs_generator", "chs_solar", "chs_windmill", "chs_converter", "chs_depot", "chs_airfield", "chs_advairfield", "chs_airpad", "chs_thorn", "chs_eye" },
	pieces = { "base", "nano" },
	icon = "worker",
	model = "chs_vulture",
})
