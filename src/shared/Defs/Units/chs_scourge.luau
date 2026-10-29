--!strict
local Templates = require("../Templates")

-- T2 missile battery (S-106, the user's pick (a) of S-96's T2 defenses):
-- radar-guided missiles against ground targets, artillery first, from
-- beyond mobile artillery's range. Placeholder numbers.
return Templates.extend(Templates.Structure, {
	id = "chs_scourge",
	name = "Scourge",
	description = "Missile battery. Fires radar-guided missiles at ground targets, artillery first.",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 320, power = 3600, buildTime = 7000 },
	health = 2100,
	footprint = 3, -- size shows tech level (S-104)
	sensors = { sight = 200 },
	weapons = { { def = "chs_scourge_missile", turretPiece = "launcher", muzzle = "muzzle" } },
	pieces = { "base", "launcher", "muzzle" },
	icon = "artillery",
	model = "chs_scourge",
})
