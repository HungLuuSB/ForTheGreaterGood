--!strict
local Templates = require("../Templates")

-- Chaos T1 twin laser tower (S-157, the user): two Guard barrels, more range.
return Templates.extend(Templates.Structure, {
	id = "chs_twin_guard",
	name = "Twin Guard",
	description = "Twin laser tower. Two red laser barrels firing in turn.",
	faction = "chaos",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 180, power = 1500, buildTime = 4000 },
	-- S-179, the playtest's balance notes: health × 2
	health = 2400,
	footprint = 2, -- size shows tech level (S-104)
	height = 17.5, -- a tall tower (S-184; models-C's F18 blockouts, measured)
	muzzleHeight = 16.0,
	sensors = { sight = 230 },
	weapons = { { def = "chs_twin_laser", turretPiece = "turret", pitchPiece = "mount", muzzle = "muzzle1", muzzles = { "muzzle1", "muzzle2" } } },
	pieces = { "base", "turret", "mount", "muzzle1", "muzzle2" }, -- the mount pitches both barrels (models-C, the user)
	icon = "turret",
	model = "chs_twin_guard",
})
