--!strict
local Templates = require("../Templates")

-- Chaos T2 flak tower (S-96, client request 43: more T2 defenses): three
-- lighter flak guns, cheaper than Order's Lumen.
return Templates.extend(Templates.Structure, {
	id = "chs_hailstorm",
	name = "Sleet", -- Hailstorm until S-225: BAR's Hailstorm is a different unit
	description = "Flak tower. Three flak guns against aircraft.",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 220, power = 2200, buildTime = 5200 },
	health = 2000,
	footprint = 2, -- size shows tech level (S-104)
	sensors = { sight = 180, airSight = 300 },
	weapons = {
		{ def = "chs_flak", turretPiece = "turret", muzzle = "muzzle" },
		{ def = "chs_flak", turretPiece = "turret", muzzle = "muzzle2" },
		{ def = "chs_flak", turretPiece = "turret", muzzle = "muzzle3" },
	},
	pieces = { "base", "turret", "muzzle", "muzzle2", "muzzle3" },
	icon = "aa",
	model = "chs_hailstorm",
})
