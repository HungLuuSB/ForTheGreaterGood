--!strict
-- Centurion: Chaos's heavy laser bot that clears swarms (S-181, the playtest's new units).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_centurion",
	name = "Centurion",
	description = "Heavy bot. A long red laser that cuts through a line of units.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 2,
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	cost = { supply = 650, power = 7500, buildTime = 17000 },
	health = 5200,
	movement = { maxSpeed = 14.4, accel = 16, brake = 28, turnRate = 360 },
	sensors = { sight = 200 },
	weapons = { { def = "chs_centurion_laser", turretPiece = "torso", muzzle = "muzzle" } },
	pieces = { "base", "torso", "muzzle" },
	icon = "tank_heavy",
	model = "chs_centurion",
})
