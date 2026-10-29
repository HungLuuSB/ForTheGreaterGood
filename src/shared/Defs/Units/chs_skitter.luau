--!strict
-- Skitter: Chaos's scout bot, a stream of plasma (S-181, the playtest's new units).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_skitter",
	name = "Skitter",
	description = "Scout bot. A fast walker that sprays small plasma bolts.",
	faction = "chaos",
	tier = 1,
	domain = "ground",
	moveClass = "WALKER", -- bots climb steep slopes and turn on the spot
	footprint = 1,
	categories = { "GROUND", "LIGHT" },
	armorClass = "LIGHT",
	cost = { supply = 50, power = 580, buildTime = 1400 },
	health = 300,
	movement = { maxSpeed = 43.2, accel = 64, brake = 72, turnRate = 500 },
	sensors = { sight = 270 },
	weapons = { { def = "chs_skitter_plasma", turretPiece = "torso", muzzle = "muzzle" } },
	pieces = { "base", "torso", "muzzle" },
	icon = "scout",
	model = "chs_skitter",
})
