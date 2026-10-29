--!strict
-- Tinker: Chaos's bot constructor (S-181, the playtest's new units).
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "chs_tinker",
	name = "Tinker",
	description = "Bot constructor. Less build power and health than the Scrapper, but climbs anywhere.",
	faction = "chaos",
	domain = "ground",
	moveClass = "WALKER", -- bots climb steep slopes and turn on the spot
	footprint = 1,
	categories = { "GROUND", "WORKER" },
	cost = { supply = 90, power = 1050, buildTime = 2400 },
	health = 420,
	movement = { maxSpeed = 22.8, accel = 32, brake = 42, turnRate = 400 },
	sensors = { sight = 95 },
	buildPower = 70,
	buildRange = 40,
	canResurrect = true,
	buildOptions = { "chs_extractor", "chs_solar", "chs_advsolar", "chs_accumulator", "chs_windmill", "chs_converter", "chs_depot", "chs_botlab", "chs_advbotlab", "chs_guard", "chs_twin_guard", "chs_geryon", "chs_talos", "chs_thorn", "chs_eye", "chs_smog", "chs_nano" },
	icon = "worker",
	model = "chs_tinker",
})
