--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.1 "Advanced Naval Worker", T2); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_reaver",
	name = "Reaver",
	description = "Advanced naval worker. Builds and reclaims.",
	faction = "chaos",
	tier = 2,
	domain = "naval",
	categories = { "NAVAL", "WORKER" },
	armorClass = "SHIP",
	moveClass = "SHIP",
	footprint = 1,
	cost = { supply = 320, power = 4200, buildTime = 8200 },
	health = 1400,
	movement = { maxSpeed = 26, accel = 8, brake = 12, turnRate = 60 },
	sensors = { sight = 120 },
	buildPower = 200,
	buildRange = 45, -- 70% of 64 (client request 7, S-19)
	buildOptions = { "chs_tidal", "chs_advextractor", "chs_fusion", "chs_shipyard", "chs_advshipyard", "chs_breaker", "chs_deepear", "chs_scylla" },
	pieces = { "base", "nano" },
	icon = "worker",
	model = "chs_reaver",
})
