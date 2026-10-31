--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.4); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_corsair",
	name = "Cutthroat", -- Corsair until S-225: BAR's Corsair is a different unit
	description = "Destroyer. Sonar, a gun, anti-submarine torpedoes and a naval SAM.",
	faction = "chaos",
	tier = 2,
	domain = "naval",
	categories = { "NAVAL" },
	armorClass = "SHIP",
	moveClass = "SHIP",
	footprint = 3,
	cost = { supply = 400, power = 4000, buildTime = 10500 },
	health = 2800,
	movement = { maxSpeed = 14.4, accel = 7, brake = 11, turnRate = 42 },
	sensors = { sight = 240, sonar = 300 },
	weapons = { { def = "chs_naval_gun", turretPiece = "turret1", muzzle = "muzzle1" }, { def = "chs_asw_torpedo", turretPiece = "turret2", muzzle = "muzzle2" }, { def = "chs_naval_sam", turretPiece = "launcher", muzzle = "muzzle3" } },
	pieces = { "base", "turret1", "turret2", "launcher", "muzzle1", "muzzle2", "muzzle3" },
	model = "chs_corsair",
	icon = "destroyer",
})
