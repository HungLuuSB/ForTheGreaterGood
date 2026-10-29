--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.4); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_lamprey",
	name = "Lamprey",
	description = "Submarine. Stays submerged and fires torpedoes.",
	faction = "chaos",
	tier = 1,
	domain = "naval",
	categories = { "SUB" },
	armorClass = "SUB",
	moveClass = "SUB",
	footprint = 1,
	cost = { supply = 150, power = 1500, buildTime = 4200 },
	health = 950,
	movement = { maxSpeed = 12.6, accel = 6, brake = 10, turnRate = 48 },
	sensors = { sight = 110, sonar = 240 },
	weapons = { { def = "chs_torpedo", turretPiece = "turret1", muzzle = "muzzle1" } },
	pieces = { "base", "turret1", "turret2", "muzzle1", "muzzle2" },
	model = "chs_lamprey",
	icon = "submarine",
})
