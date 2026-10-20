--!strict
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "chs_scrapper",
	name = "Scrapper",
	description = "Ground worker. Builds T1 economy and the Vehicle Foundry; reclaims wrecks.",
	faction = "chaos",
	cost = { supply = 110, power = 1300, buildTime = 2800 },
	health = 700,
	movement = { maxSpeed = 28, accel = 11, brake = 22, turnRate = 100 },
	sensors = { sight = 95 },
	buildPower = 100,
	buildRange = 64,
	buildOptions = { "chs_extractor", "chs_generator", "chs_vehplant" },
	model = "chs_scrapper",
})
