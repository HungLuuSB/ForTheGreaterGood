--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.4); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_corsair",
	name = "Corsair",
	description = "Destroyer. Sonar, gun and anti-submarine torpedoes.",
	faction = "chaos",
	tier = 2,
	domain = "naval",
	categories = { "NAVAL" },
	armorClass = "SHIP",
	moveClass = "SHIP",
	footprint = 3,
	cost = { supply = 400, power = 4000, buildTime = 10500 },
	health = 2800,
	movement = { maxSpeed = 24, accel = 7, brake = 11, turnRate = 42 },
	sensors = { sight = 240, sonar = 300 },
	weapons = { { def = "chs_naval_gun", turretPiece = "turret1", muzzle = "muzzle1" }, { def = "chs_asw_torpedo", turretPiece = "turret2", muzzle = "muzzle2" } },
	pieces = { "base", "turret1", "turret2", "muzzle1", "muzzle2" },
	model = "chs_corsair",
	icon = "destroyer",
})
