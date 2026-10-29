--!strict
local Templates = require("../Templates")

-- Nuclear missile silo (guide 13.5, T3; S-48, client request 26). Stats to balance.
return Templates.extend(Templates.Structure, {
	id = "chs_ragnarok",
	name = "Ragnarok",
	description = "Nuclear missile silo. Builds warheads and launches one at any spot on the map.",
	faction = "chaos",
	tier = 3,
	categories = { "STRUCTURE" },
	cost = { supply = 2400, power = 24000, buildTime = 48000 },
	health = 7000,
	footprint = 6, -- size shows tech level (S-104)
	sensors = { sight = 160 },
	weapons = { { def = "chs_nuke", muzzle = "muzzle" } },
	pieces = { "base", "hatch", "muzzle" },
	icon = "nuke",
	model = "chs_ragnarok",
})
