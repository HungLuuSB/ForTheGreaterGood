--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.2 "Scout", T1); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_jackal",
	name = "Jackal",
	description = "Scout. Fast, wide sight, light gun.",
	faction = "chaos",
	tier = 1,
	domain = "ground",
	categories = { "GROUND", "LIGHT" },
	armorClass = "LIGHT",
	moveClass = "WHEELED",
	footprint = 1,
	cost = { supply = 50, power = 600, buildTime = 1500 },
	health = 320,
	movement = { maxSpeed = 66, accel = 30, brake = 50, turnRate = 180 },
	sensors = { sight = 260 },
	weapons = { { def = "chs_mg", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "scout",
	model = "chs_jackal",
})
