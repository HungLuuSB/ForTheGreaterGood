--!strict
local Templates = require("../Templates")

-- Nuclear missile silo (guide 13.5, T3; S-48, client request 26). Stats to balance.
return Templates.extend(Templates.Structure, {
	id = "ord_reckoning",
	name = "Reckoning",
	description = "Nuclear missile silo. Builds warheads into a stockpile; launches one at an ordered spot anywhere on the map.",
	faction = "order",
	tier = 3,
	categories = { "STRUCTURE" },
	cost = { supply = 2400, power = 24000, buildTime = 48000 },
	health = 7000,
	footprint = 3,
	sensors = { sight = 160 },
	weapons = { { def = "ord_nuke", muzzle = "muzzle" } },
	pieces = { "base", "hatch", "muzzle" },
	icon = "nuke",
	model = "ord_reckoning",
})
