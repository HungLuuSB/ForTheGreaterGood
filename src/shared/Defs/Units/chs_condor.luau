--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.1 "Advanced Air Worker", T2); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_condor",
	name = "Carrion", -- Condor until S-225: BAR's Condor is a different unit
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
	movement = { maxSpeed = 45, accel = 30, brake = 40, turnRate = 210 },
	sensors = { sight = 120 },
	buildPower = 180,
	buildRange = 34, -- 70% of 48 (client request 7, S-19)
	buildOptions = { "chs_extractor", "chs_solar", "chs_windmill", "chs_converter", "chs_depot", "chs_advextractor", "chs_fusion", "chs_airfield", "chs_advairfield", "chs_airpad", "chs_rookery", "chs_allseer", "chs_wyvern" },
	buildsLike = { "chs_forgemaster" }, -- and everything they build (S-206, the user's H35)
	pieces = { "base", "nano" },
	icon = "worker",
	model = "chs_condor",
})
