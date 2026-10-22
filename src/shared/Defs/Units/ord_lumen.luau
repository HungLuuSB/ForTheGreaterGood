--!strict
local Templates = require("../Templates")

-- Order T2 flak tower (S-96, client request 43: more T2 defenses): two
-- flak guns against aircraft over a base.
return Templates.extend(Templates.Structure, {
	id = "ord_lumen",
	name = "Lumen",
	description = "Flak tower. Two flak guns against aircraft.",
	faction = "order",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 260, power = 2600, buildTime = 6000 },
	health = 2400,
	footprint = 1,
	sensors = { sight = 200, airSight = 320 },
	weapons = {
		{ def = "ord_flak", turretPiece = "turret", muzzle = "muzzle" },
		{ def = "ord_flak", turretPiece = "turret", muzzle = "muzzle2" },
	},
	pieces = { "base", "turret", "muzzle", "muzzle2" },
	icon = "aa",
	model = "ord_lumen",
})
