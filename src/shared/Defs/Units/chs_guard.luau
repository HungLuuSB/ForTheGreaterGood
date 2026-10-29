--!strict
local Templates = require("../Templates")

-- Chaos T1 basic tower (S-157, the user): like Sentry, a red laser. Replaces
-- the Spike gun turret on the build lists.
return Templates.extend(Templates.Structure, {
	id = "chs_guard",
	name = "Guard",
	description = "Laser tower. Fires a quick red laser.",
	faction = "chaos",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 100, power = 750, buildTime = 2100 },
	-- S-179, the playtest's balance notes: health × 2
	health = 1500,
	footprint = 2, -- size shows tech level (S-104)
	height = 17.5, -- a tall tower (S-184; models-C's F18 blockouts, measured)
	muzzleHeight = 16.0,
	sensors = { sight = 210 },
	weapons = { { def = "chs_guard_laser", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	pieces = { "base", "turret", "barrel", "muzzle" }, -- barrel pitches (models-C, the user)
	icon = "turret",
	model = "chs_guard",
})
