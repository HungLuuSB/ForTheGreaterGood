--!strict
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "ord_sovereign",
	name = "Sovereign",
	description = "Command Vehicle. Builds the first economy and factories. Losing it loses the match.",
	faction = "order",
	tier = 0,
	categories = { "GROUND", "WORKER", "COMMANDER" },
	cost = { supply = 1000, power = 10000, buildTime = 30000 },
	health = 3000,
	movement = { maxSpeed = 24, accel = 10, brake = 20, turnRate = 90 },
	sensors = { sight = 140 },
	buildPower = 300,
	footprint = 2, -- a 10-stud walking mech (S-124, the user via models-C)
	buildRange = 60, -- 70% of 80 (client request 7, S-19), + 4 for the bigger body (S-124: the reach from its edge stays)
	buildOptions = { "ord_extractor", "ord_generator", "ord_solar", "ord_windmill", "ord_converter", "ord_depot", "ord_vehplant", "ord_airfield", "ord_shipyard", "ord_bulwark", "ord_watchtower" },
	production = { supply = 1, power = 20 },
	model = "ord_sovereign",
	icon = "commander",
})
