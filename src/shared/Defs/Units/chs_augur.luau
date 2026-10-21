--!strict
local Templates = require("../Templates")

-- Pinpointer (guide 11.4, 13.5, T2; S-59, client request 34). Stats to balance.
return Templates.extend(Templates.Structure, {
	id = "chs_augur",
	name = "Augur",
	description = "Pinpointer. Each one sharpens the team's radar: contacts wobble less and radar missiles hold their lock (full at 6).",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 250, power = 3000, buildTime = 6000 },
	health = 1000,
	footprint = 2,
	sensors = { sight = 120 },
	pinpointer = true,
	pieces = { "base", "dish" },
	icon = "pinpointer",
	model = "chs_augur",
})
