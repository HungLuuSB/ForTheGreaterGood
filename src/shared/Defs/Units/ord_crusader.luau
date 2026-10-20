--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.4); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "ord_crusader",
	name = "Crusader",
	description = "Destroyer. Sonar, gun and anti-submarine torpedoes.",
	faction = "order",
	tier = 2,
	domain = "naval",
	categories = { "NAVAL" },
	armorClass = "SHIP",
	moveClass = "SHIP",
	footprint = 3,
	cost = { supply = 420, power = 4200, buildTime = 11000 },
	health = 2600,
	movement = { maxSpeed = 26, accel = 7, brake = 11, turnRate = 45 },
	sensors = { sight = 260, sonar = 320 },
	weapons = { { def = "ord_naval_gun", turretPiece = "turret1", muzzle = "muzzle1" }, { def = "ord_asw_torpedo", turretPiece = "turret2", muzzle = "muzzle2" } },
	pieces = { "base", "turret1", "turret2", "muzzle1", "muzzle2" },
	model = "ord_crusader",
	icon = "destroyer",
})
