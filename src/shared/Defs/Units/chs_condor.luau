--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.1 "Advanced Air Worker", T2); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_condor",
	name = "Condor",
	description = "Advanced air worker. Builds and reclaims.",
	faction = "chaos",
	tier = 2,
	domain = "air",
	categories = { "AIR", "HELI", "WORKER" },
	armorClass = "AIR",
	moveClass = "HELI",
	footprint = 1,
	cost = { supply = 320, power = 5000, buildTime = 9000 },
	health = 700,
	movement = { maxSpeed = 75, accel = 30, brake = 40, turnRate = 140 },
	sensors = { sight = 120 },
	buildPower = 180,
	buildRange = 48,
	buildOptions = { "chs_extractor", "chs_generator", "chs_solar", "chs_windmill", "chs_converter", "chs_depot", "chs_advextractor", "chs_fusion", "chs_airfield", "chs_advairfield", "chs_airpad", "chs_allseer", "chs_wyvern" },
	pieces = { "base", "nano" },
	icon = "worker",
	model = "chs_condor",
})
