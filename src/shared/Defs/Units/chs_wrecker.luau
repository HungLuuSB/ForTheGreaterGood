--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.1 "Naval Worker", T1); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_wrecker",
	name = "Wrecker",
	description = "Naval worker. Builds and reclaims.",
	faction = "chaos",
	tier = 1,
	domain = "naval",
	categories = { "NAVAL", "WORKER" },
	armorClass = "SHIP",
	moveClass = "SHIP",
	footprint = 1,
	cost = { supply = 140, power = 1800, buildTime = 3600 },
	health = 800,
	movement = { maxSpeed = 18, accel = 10, brake = 14, turnRate = 70 },
	sensors = { sight = 120 },
	buildPower = 100,
	buildRange = 45, -- 70% of 64 (client request 7, S-19)
	buildOptions = { "chs_extractor", "chs_seaextractor", "chs_solar", "chs_advsolar", "chs_accumulator", "chs_windmill", "chs_converter", "chs_depot", "chs_tidal", "chs_shipyard", "chs_advshipyard", "chs_riptide", "chs_fang", "chs_listener", "chs_nano" },
	pieces = { "base", "nano" },
	icon = "worker",
	model = "chs_wrecker",
})
