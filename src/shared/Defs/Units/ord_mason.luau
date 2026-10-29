--!strict
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "ord_mason",
	name = "Mason",
	description = "Ground worker. Builds T1 economy and the Vehicle Plant; reclaims wrecks.",
	faction = "order",
	cost = { supply = 135, power = 1650, buildTime = 3300 },
	health = 750, -- faction pass (S-62)
	movement = { maxSpeed = 16.8, accel = 12, brake = 24, turnRate = 110 },
	sensors = { sight = 100 },
	buildPower = 110, -- faction pass (S-62)
	canResurrect = true, -- T1 workers resurrect wrecks (S-168, the user)
	buildRange = 45, -- 70% of 64 (client request 7, S-19)
	buildOptions = { "ord_extractor", "ord_solar", "ord_advsolar", "ord_capacitor", "ord_windmill", "ord_converter", "ord_depot", "ord_vehplant", "ord_botlab", "ord_advvehplant", "ord_sentry_tower", "ord_beamer", "ord_overwatch", "ord_gauntlet", "ord_vigil", "ord_watchtower", "ord_curtain", "ord_barrier", "ord_nano" },
	model = "ord_mason",
})
