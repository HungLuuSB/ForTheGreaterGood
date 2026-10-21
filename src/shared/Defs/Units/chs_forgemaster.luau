--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.1 "Advanced Ground Worker", T2); stats to balance in M8.
return Templates.extend(Templates.Builder, {
	id = "chs_forgemaster",
	name = "Forgemaster",
	description = "Advanced ground worker. Builds and reclaims.",
	faction = "chaos",
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
	buildRange = 45, -- 70% of 64 (client request 7, S-19)
	buildOptions = { "chs_extractor", "chs_generator", "chs_solar", "chs_windmill", "chs_converter", "chs_depot", "chs_advextractor", "chs_fusion", "chs_advvehplant", "chs_maw", "chs_wyvern", "chs_cataclysm", "chs_allseer", "chs_blackout", "chs_seekerspire", "chs_ragnarok" },
	pieces = { "base", "nano" },
	icon = "worker",
	model = "chs_forgemaster",
})
