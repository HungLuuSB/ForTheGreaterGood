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
	footprint = 2, -- a 10-stud walking mech (S-124, the user via models-C)
	moveClass = "WALKER", -- climbs 40° slopes, BAR-bot style (S-159)
	buildRange = 60, -- 70% of 80 (client request 7, S-19), + 4 for the bigger body (S-124: the reach from its edge stays)
	buildOptions = { "chs_extractor", "chs_generator", "chs_solar", "chs_windmill", "chs_converter", "chs_depot", "chs_vehplant", "chs_airfield", "chs_shipyard", "chs_guard", "chs_eye" },
	production = { supply = 1, power = 20 },
	deathBlast = { damage = 4000, aoe = 120, edge = 0.15 }, -- a Commander goes up in a huge blast, smaller than a nuke's 150 (S-178, F15)
	model = "chs_warlord",
	icon = "commander",
})
