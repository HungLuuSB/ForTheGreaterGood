--!strict
local Templates = require("../Templates")

-- Order T1 heavy laser tower (S-157, the user): two barrels left-right-left.
return Templates.extend(Templates.Structure, {
	id = "ord_overwatch",
	name = "Overwatch",
	description = "Twin laser tower. Two green barrels firing in turn: fast, hard-hitting, long range.",
	faction = "order",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 220, power = 1800, buildTime = 4800 },
	-- S-179, the playtest's balance notes: health × 2
	health = 2800,
	footprint = 2, -- size shows tech level (S-104)
	sensors = { sight = 260 },
	weapons = { { def = "ord_overwatch_laser", turretPiece = "turret", pitchPiece = "mount", muzzle = "muzzle1", muzzles = { "muzzle1", "muzzle2" } } },
	pieces = { "base", "turret", "mount", "muzzle1", "muzzle2" }, -- the mount pitches both barrels (models-C, the user)
	icon = "turret",
	model = "ord_overwatch",
})
