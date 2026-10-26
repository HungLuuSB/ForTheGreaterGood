--!strict
-- Glint: Order's scout bot, a laser on each arm (S-181, the playtest's new units).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "ord_glint",
	name = "Glint",
	description = "Scout bot. Fast, a little tougher than the Skitter; lasers from both arms in turn.",
	faction = "order",
	tier = 1,
	domain = "ground",
	moveClass = "WALKER", -- bots climb steep slopes and turn on the spot
	footprint = 1,
	categories = { "GROUND", "LIGHT" },
	armorClass = "LIGHT",
	cost = { supply = 60, power = 700, buildTime = 1700 },
	health = 380,
	movement = { maxSpeed = 39.6, accel = 60, brake = 70, turnRate = 500 },
	sensors = { sight = 280 },
	weapons = { { def = "ord_glint_laser", turretPiece = "torso", muzzle = "arm_l_muzzle", muzzles = { "arm_l_muzzle", "arm_r_muzzle" } } },
	pieces = { "base", "torso", "arm_l", "arm_r", "arm_l_muzzle", "arm_r_muzzle" },
	icon = "scout",
	model = "ord_glint",
})
