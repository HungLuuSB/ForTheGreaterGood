--!strict
local Templates = require("../Templates")

-- Pinpointer (guide 11.4, 13.5, T2; S-59, client request 34). Stats to balance.
return Templates.extend(Templates.Structure, {
	id = "chs_augur",
	name = "Augur",
	description = "Pinpointer. Each one sharpens the team's radar: contacts wobble less and radar missiles hold their lock; full effect at 7.",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 215, power = 2550, buildTime = 5100 },
	health = 850, -- faction pass (S-62)
	footprint = 2,
	sensors = { sight = 120 },
	pinpointer = true,
	pinpointFull = 7, -- full at 7 (faction pass, S-62)
	pieces = { "base", "dish" },
	icon = "pinpointer",
	model = "chs_augur",
})
