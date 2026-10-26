--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.1 "Advanced Air Worker", T2); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "ord_zenith",
	name = "Zenith",
	description = "Advanced air worker. Builds and reclaims.",
	faction = "order",
	tier = 2,
	domain = "air",
	categories = { "AIR", "HELI", "WORKER" },
	armorClass = "AIR",
	moveClass = "HELI",
	footprint = 1,
	cost = { supply = 320, power = 5000, buildTime = 9000 },
	health = 700,
	movement = { maxSpeed = 45, accel = 30, brake = 40, turnRate = 210 },
	sensors = { sight = 120 },
	buildPower = 180,
	buildRange = 34, -- 70% of 48 (client request 7, S-19)
	buildOptions = { "ord_extractor", "ord_generator", "ord_solar", "ord_windmill", "ord_converter", "ord_depot", "ord_advextractor", "ord_fusion", "ord_airfield", "ord_advairfield", "ord_airpad", "ord_empyrean", "ord_beacon", "ord_aegis" },
	pieces = { "base", "nano" },
	icon = "worker",
	model = "ord_zenith",
})
