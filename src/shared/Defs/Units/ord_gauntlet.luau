--!strict
local Templates = require("../Templates")

-- Order T1 lobbing gun (S-157, the user): high-trajectory shells, medium
-- range. It can't hit what's right next to it (the barrel tops out at 85°).
return Templates.extend(Templates.Structure, {
	id = "ord_gauntlet",
	name = "Gauntlet",
	description = "Lobbing gun. Fires shells on a high arc, over walls.",
	faction = "order",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 240, power = 2000, buildTime = 5200 },
	-- S-179, the playtest's balance notes: health × 2
	health = 2000,
	footprint = 2, -- size shows tech level (S-104)
	sensors = { sight = 240 },
	weapons = { { def = "ord_gauntlet_shell", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	pieces = { "base", "turret", "barrel", "muzzle" },
	icon = "artillery",
	model = "ord_gauntlet",
})
