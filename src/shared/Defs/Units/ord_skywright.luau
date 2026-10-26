--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.1 "Air Worker", T1); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "ord_skywright",
	name = "Skywright",
	description = "Air worker. Builds and reclaims.",
	faction = "order",
	tier = 1,
	domain = "air",
	categories = { "AIR", "HELI", "WORKER" },
	armorClass = "AIR",
	moveClass = "HELI",
	footprint = 1,
	cost = { supply = 140, power = 2400, buildTime = 4200 },
	health = 420,
	movement = { maxSpeed = 42, accel = 30, brake = 40, turnRate = 210 },
	sensors = { sight = 120 },
	buildPower = 90,
	buildRange = 34, -- 70% of 48 (client request 7, S-19)
	buildOptions = { "ord_extractor", "ord_generator", "ord_solar", "ord_windmill", "ord_converter", "ord_depot", "ord_airfield", "ord_advairfield", "ord_airpad", "ord_vigil", "ord_watchtower" },
	pieces = { "base", "nano" },
	icon = "worker",
	model = "ord_skywright",
})
