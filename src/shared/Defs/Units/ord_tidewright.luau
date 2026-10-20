--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.1 "Naval Worker", T1); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "ord_tidewright",
	name = "Tidewright",
	description = "Naval worker. Builds and reclaims.",
	faction = "order",
	tier = 1,
	domain = "naval",
	categories = { "NAVAL", "WORKER" },
	armorClass = "SHIP",
	moveClass = "SHIP",
	footprint = 1,
	cost = { supply = 140, power = 1800, buildTime = 3600 },
	health = 800,
	movement = { maxSpeed = 30, accel = 10, brake = 14, turnRate = 70 },
	sensors = { sight = 120 },
	buildPower = 100,
	buildRange = 64,
	buildOptions = { "ord_extractor", "ord_generator", "ord_solar", "ord_windmill", "ord_converter", "ord_depot", "ord_tidal", "ord_shipyard", "ord_advshipyard", "ord_moat", "ord_undertow", "ord_ear" },
	pieces = { "base", "nano" },
	icon = "worker",
	model = "ord_tidewright",
})
