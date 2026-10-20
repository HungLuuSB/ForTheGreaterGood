--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5 "Gun turret", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_spike",
	name = "Spike",
	description = "Gun turret.",
	faction = "chaos",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 120, power = 900, buildTime = 2400 },
	health = 2000,
	footprint = 1,
	sensors = { sight = 210 },
	weapons = { { def = "chs_light_cannon", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "turret",
	model = "chs_spike",
})
