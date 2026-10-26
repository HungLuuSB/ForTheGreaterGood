--!strict
-- Thug: Chaos's assault bot (S-181, the playtest's new units).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_thug",
	name = "Thug",
	description = "Assault bot. Tough and short-ranged; a plasma cannon for breaking lines.",
	faction = "chaos",
	tier = 1,
	domain = "ground",
	moveClass = "WALKER", -- bots climb steep slopes and turn on the spot
	footprint = 1,
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	cost = { supply = 130, power = 1500, buildTime = 3300 },
	health = 1100,
	movement = { maxSpeed = 32, accel = 30, brake = 40, turnRate = 380 },
	sensors = { sight = 130 },
	weapons = { { def = "chs_thug_cannon", turretPiece = "torso", muzzle = "muzzle" } },
	pieces = { "base", "torso", "muzzle" },
	icon = "tank_light",
	model = "chs_thug",
})
