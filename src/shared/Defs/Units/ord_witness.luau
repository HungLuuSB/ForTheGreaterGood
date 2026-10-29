--!strict
local Templates = require("../Templates")

-- Pinpointer (guide 11.4, 13.5, T2; S-59, client request 34). Stats to balance.
return Templates.extend(Templates.Structure, {
	id = "ord_witness",
	name = "Witness",
	description = "Pinpointer. Each one sharpens the team's radar: contacts wobble less and radar missiles hold their lock; full effect at 5.",
	faction = "order",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 290, power = 3400, buildTime = 6900 },
	health = 1150, -- faction pass (S-62)
	footprint = 2,
	sensors = { sight = 120 },
	pinpointer = true,
	pinpointFull = 5, -- full at 5 (faction pass, S-62)
	pieces = { "base", "dish" },
	icon = "pinpointer",
	model = "ord_witness",
})
