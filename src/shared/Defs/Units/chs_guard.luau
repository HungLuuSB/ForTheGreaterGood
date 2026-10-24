--!strict
local Templates = require("../Templates")

-- Chaos T1 basic tower (S-157, the user): like Sentry, a red laser. Replaces
-- the Spike gun turret on the build lists.
return Templates.extend(Templates.Structure, {
	id = "chs_guard",
	name = "Guard",
	description = "Laser tower. Cheap, quick red laser.",
	faction = "chaos",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 100, power = 750, buildTime = 2100 },
	health = 750,
	footprint = 2, -- size shows tech level (S-104)
	sensors = { sight = 210 },
	weapons = { { def = "chs_guard_laser", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "turret",
	model = "chs_guard",
})
