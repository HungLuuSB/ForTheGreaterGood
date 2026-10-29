--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.4); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "ord_silence",
	name = "Silence",
	description = "Submarine. Stays submerged and fires torpedoes.",
	faction = "order",
	tier = 1,
	domain = "naval",
	categories = { "SUB" },
	armorClass = "SUB",
	moveClass = "SUB",
	footprint = 1,
	cost = { supply = 160, power = 1600, buildTime = 4400 },
	health = 900,
	movement = { maxSpeed = 13.2, accel = 6, brake = 10, turnRate = 50 },
	sensors = { sight = 120, sonar = 260 },
	weapons = { { def = "ord_torpedo", turretPiece = "turret1", muzzle = "muzzle1" } },
	pieces = { "base", "turret1", "turret2", "muzzle1", "muzzle2" },
	model = "ord_silence",
	icon = "submarine",
})
