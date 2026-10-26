--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.1 "Advanced Naval Worker", T2); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "ord_harbormaster",
	name = "Harbormaster",
	description = "Advanced naval worker. Builds and reclaims.",
	faction = "order",
	tier = 2,
	domain = "naval",
	categories = { "NAVAL", "WORKER" },
	armorClass = "SHIP",
	moveClass = "SHIP",
	footprint = 1,
	cost = { supply = 320, power = 4200, buildTime = 8200 },
	health = 1400,
	movement = { maxSpeed = 15.6, accel = 8, brake = 12, turnRate = 60 },
	sensors = { sight = 120 },
	buildPower = 200,
	buildRange = 45, -- 70% of 64 (client request 7, S-19)
	buildOptions = { "ord_tidal", "ord_advextractor", "ord_fusion", "ord_shipyard", "ord_advshipyard", "ord_rampart", "ord_choir", "ord_pharos" },
	pieces = { "base", "nano" },
	icon = "worker",
	model = "ord_harbormaster",
})
