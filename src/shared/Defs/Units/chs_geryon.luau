--!strict
local Templates = require("../Templates")

-- Chaos T1 heavy laser tower (S-157, the user; Geryon, the three-bodied
-- giant): three barrels on a drum, only the top one fires, then the drum
-- turns 120° (client). Overwatch's counterpart: more damage, less range.
return Templates.extend(Templates.Structure, {
	id = "chs_geryon",
	name = "Geryon",
	description = "Triple laser tower. A three-barrel drum: hard-hitting green shots, shorter range than Overwatch.",
	faction = "chaos",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 220, power = 1800, buildTime = 4800 },
	health = 1500,
	footprint = 2, -- size shows tech level (S-104)
	sensors = { sight = 240 },
	weapons = { { def = "chs_geryon_laser", turretPiece = "turret", muzzle = "muzzle1", muzzles = { "muzzle1", "muzzle2", "muzzle3" }, drumPiece = "drum" } },
	pieces = { "base", "turret", "drum", "muzzle1", "muzzle2", "muzzle3" },
	icon = "turret",
	model = "chs_geryon",
})
