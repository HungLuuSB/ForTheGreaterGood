--!strict
local Templates = require("../Templates")

-- Order T1 basic tower (S-157, the user): a red laser. Replaces the Bulwark gun
-- turret on the build lists. Placeholder numbers like the rest.
return Templates.extend(Templates.Structure, {
	id = "ord_sentry_tower",
	name = "Sentry",
	description = "Laser tower. Cheap, quick red laser.",
	faction = "order",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 110, power = 800, buildTime = 2200 },
	health = 800,
	footprint = 2, -- size shows tech level (S-104)
	sensors = { sight = 230 },
	weapons = { { def = "ord_sentry_laser", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	pieces = { "base", "turret", "barrel", "muzzle" }, -- barrel pitches (models-C, the user)
	icon = "turret",
	model = "ord_sentry_tower",
})
