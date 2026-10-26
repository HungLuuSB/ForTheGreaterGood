--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.4); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "ord_crusader",
	name = "Crusader",
	description = "Destroyer. Sonar, gun, anti-submarine torpedoes and a naval SAM.",
	faction = "order",
	tier = 2,
	domain = "naval",
	categories = { "NAVAL" },
	armorClass = "SHIP",
	moveClass = "SHIP",
	footprint = 3,
	cost = { supply = 420, power = 4200, buildTime = 11000 },
	health = 2600,
	movement = { maxSpeed = 15.6, accel = 7, brake = 11, turnRate = 45 },
	sensors = { sight = 260, sonar = 320 },
	weapons = { { def = "ord_naval_gun", turretPiece = "turret1", muzzle = "muzzle1" }, { def = "ord_asw_torpedo", turretPiece = "turret2", muzzle = "muzzle2" }, { def = "ord_naval_sam", turretPiece = "launcher", muzzle = "muzzle3" } },
	pieces = { "base", "turret1", "turret2", "launcher", "muzzle1", "muzzle2", "muzzle3" },
	model = "ord_crusader",
	icon = "destroyer",
})
