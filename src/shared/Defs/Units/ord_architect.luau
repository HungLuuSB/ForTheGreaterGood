--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.1 "Advanced Ground Worker", T2); stats to balance in M8.
return Templates.extend(Templates.Builder, {
	id = "ord_architect",
	name = "Architect",
	description = "Advanced ground worker. Builds and reclaims.",
	faction = "order",
	tier = 2,
	domain = "ground",
	categories = { "GROUND", "WORKER" },
	armorClass = "ARMORED",
	moveClass = "TRACKED",
	footprint = 1,
	cost = { supply = 300, power = 4000, buildTime = 8000 },
	health = 1100,
	movement = { maxSpeed = 28, accel = 11, brake = 22, turnRate = 100 },
	sensors = { sight = 120 },
	buildPower = 200,
	buildRange = 64,
	buildOptions = { "ord_extractor", "ord_generator", "ord_solar", "ord_windmill", "ord_converter", "ord_depot", "ord_advextractor", "ord_fusion", "ord_advvehplant", "ord_bastion", "ord_aegis", "ord_edict", "ord_beacon", "ord_veilspire" },
	pieces = { "base", "nano" },
	icon = "worker",
	model = "ord_architect",
})
