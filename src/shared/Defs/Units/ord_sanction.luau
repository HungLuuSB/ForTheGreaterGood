--!strict
local Templates = require("../Templates")

-- T2 missile battery (S-106, the user's pick (a) of S-96's T2 defenses):
-- radar-guided missiles against ground targets, artillery first, from
-- beyond mobile artillery's range. Placeholder numbers.
return Templates.extend(Templates.Structure, {
	id = "ord_sanction",
	name = "Sanction",
	description = "Missile battery. Fires radar-guided missiles at ground targets, artillery first.",
	faction = "order",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 380, power = 4200, buildTime = 8000 },
	health = 2600,
	footprint = 3, -- size shows tech level (S-104)
	sensors = { sight = 200 },
	weapons = { { def = "ord_sanction_missile", turretPiece = "launcher", muzzle = "muzzle" } },
	pieces = { "base", "launcher", "muzzle" },
	icon = "artillery",
	model = "ord_sanction",
})
