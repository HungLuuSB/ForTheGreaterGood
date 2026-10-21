--!strict
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "chs_scrapper",
	name = "Scrapper",
	description = "Ground worker. Builds T1 economy and the Vehicle Foundry; reclaims wrecks.",
	faction = "chaos",
	cost = { supply = 100, power = 1200, buildTime = 2600 },
	health = 600, -- faction pass (S-62)
	movement = { maxSpeed = 32, accel = 11, brake = 22, turnRate = 100 },
	sensors = { sight = 95 },
	buildPower = 90, -- faction pass (S-62)
	buildRange = 45, -- 70% of 64 (client request 7, S-19)
	buildOptions = { "chs_extractor", "chs_generator", "chs_solar", "chs_windmill", "chs_converter", "chs_depot", "chs_vehplant", "chs_advvehplant", "chs_spike", "chs_thorn", "chs_eye", "chs_smog" },
	model = "chs_scrapper",
})
