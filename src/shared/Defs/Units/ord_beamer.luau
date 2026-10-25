--!strict
local Templates = require("../Templates")

-- Order T1 ramping beam tower (S-157, the user): outranges the Sentry; its
-- beam ramps up on one target (ord_beamer_beam).
return Templates.extend(Templates.Structure, {
	id = "ord_beamer",
	name = "Beamer",
	description = "Beam tower. A blue beam that grows stronger the longer it holds one target.",
	faction = "order",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 200, power = 1600, buildTime = 4400 },
	-- S-179, the playtest's balance notes: health × 2
	health = 2200,
	footprint = 2, -- size shows tech level (S-104)
	sensors = { sight = 250 },
	weapons = { { def = "ord_beamer_beam", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	pieces = { "base", "turret", "barrel", "muzzle" },
	icon = "beam",
	model = "ord_beamer",
})
