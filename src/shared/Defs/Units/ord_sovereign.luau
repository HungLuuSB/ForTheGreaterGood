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
	buildRange = 80,
	buildOptions = { "ord_extractor", "ord_generator", "ord_solar", "ord_depot", "ord_vehplant", "ord_airfield", "ord_shipyard", "ord_bulwark", "ord_watchtower" },
	production = { supply = 1, power = 20 },
	model = "ord_sovereign",
	icon = "commander",
})
