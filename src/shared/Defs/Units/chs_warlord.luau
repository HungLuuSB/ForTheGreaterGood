--!strict
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "chs_warlord",
	name = "Warlord",
	description = "Command Vehicle. Builds the first economy and factories. Losing it loses the match.",
	faction = "chaos",
	tier = 0,
	categories = { "GROUND", "WORKER", "COMMANDER" },
	cost = { supply = 1000, power = 10000, buildTime = 30000 },
	health = 3400,
	movement = { maxSpeed = 22, accel = 9, brake = 18, turnRate = 85 },
	sensors = { sight = 130 },
	buildPower = 300,
	buildRange = 80,
	buildOptions = { "chs_extractor", "chs_generator", "chs_vehplant" },
	production = { supply = 1, power = 20 },
	model = "chs_warlord",
	icon = "commander",
})
