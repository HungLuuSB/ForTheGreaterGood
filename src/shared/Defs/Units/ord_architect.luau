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
	cost = { supply = 330, power = 4500, buildTime = 8900 },
	health = 1270, -- faction pass (S-62)
	movement = { maxSpeed = 15.6, accel = 11, brake = 22, turnRate = 100 },
	sensors = { sight = 120 },
	buildPower = 220, -- faction pass (S-62)
	buildRange = 45, -- 70% of 64 (client request 7, S-19)
	buildOptions = { "ord_extractor", "ord_solar", "ord_windmill", "ord_converter", "ord_depot", "ord_advextractor", "ord_fusion", "ord_advconverter", "ord_advdepot", "ord_advcapacitor", "ord_advfusion", "ord_advvehplant", "ord_advbotlab", "ord_gantry", "ord_bastion", "ord_aegis", "ord_edict", "ord_beacon", "ord_veilspire", "ord_tribunal", "ord_reckoning", "ord_witness", "ord_barrier", "ord_citadel", "ord_phalanx", "ord_radiance", "ord_lumen", "ord_sanction", "ord_providence", "ord_sanctum" },
	pieces = { "base", "nano" },
	icon = "worker",
	model = "ord_architect",
})
