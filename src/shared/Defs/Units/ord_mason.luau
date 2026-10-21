--!strict
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "ord_mason",
	name = "Mason",
	description = "Ground worker. Builds T1 economy and the Vehicle Plant; reclaims wrecks.",
	faction = "order",
	cost = { supply = 120, power = 1500, buildTime = 3000 },
	health = 650,
	movement = { maxSpeed = 30, accel = 12, brake = 24, turnRate = 110 },
	sensors = { sight = 100 },
	buildPower = 100,
	buildRange = 45, -- 70% of 64 (client request 7, S-19)
	buildOptions = { "ord_extractor", "ord_generator", "ord_solar", "ord_windmill", "ord_converter", "ord_depot", "ord_vehplant", "ord_advvehplant", "ord_bulwark", "ord_vigil", "ord_watchtower", "ord_curtain" },
	model = "ord_mason",
})
