--!strict
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "chs_scrapper",
	name = "Scrapper",
	description = "Ground worker. Builds the T1 economy and the Vehicle Foundry, and reclaims wrecks.",
	faction = "chaos",
	cost = { supply = 100, power = 1200, buildTime = 2600 },
	health = 600, -- faction pass (S-62)
	movement = { maxSpeed = 19.2, accel = 11, brake = 22, turnRate = 100 },
	sensors = { sight = 95 },
	buildPower = 90, -- faction pass (S-62)
	canResurrect = true, -- T1 workers resurrect wrecks (S-168, the user)
	buildRange = 45, -- 70% of 64 (client request 7, S-19)
	buildOptions = { "chs_extractor", "chs_solar", "chs_advsolar", "chs_accumulator", "chs_windmill", "chs_converter", "chs_depot", "chs_vehplant", "chs_botlab", "chs_advvehplant", "chs_guard", "chs_twin_guard", "chs_geryon", "chs_talos", "chs_thorn", "chs_eye", "chs_smog", "chs_nano", "chs_skimyard" },
	model = "chs_scrapper",
})
