--!strict
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "ord_mason",
	name = "Mason",
	description = "Ground worker. Builds T1 economy and the Vehicle Plant; reclaims wrecks.",
	faction = "order",
	cost = { supply = 135, power = 1650, buildTime = 3300 },
	health = 750, -- faction pass (S-62)
	movement = { maxSpeed = 28, accel = 12, brake = 24, turnRate = 110 },
	sensors = { sight = 100 },
	buildPower = 110, -- faction pass (S-62)
	buildRange = 45, -- 70% of 64 (client request 7, S-19)
	buildOptions = { "ord_extractor", "ord_generator", "ord_solar", "ord_windmill", "ord_converter", "ord_depot", "ord_vehplant", "ord_advvehplant", "ord_bulwark", "ord_vigil", "ord_watchtower", "ord_curtain", "ord_barrier" },
	model = "ord_mason",
})
