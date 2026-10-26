--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.2 "Scout", T1); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "ord_herald",
	name = "Herald",
	description = "Scout. Fast, wide sight, light gun.",
	faction = "order",
	tier = 1,
	domain = "ground",
	categories = { "GROUND", "LIGHT" },
	armorClass = "LIGHT",
	moveClass = "WHEELED",
	footprint = 1,
	cost = { supply = 55, power = 660, buildTime = 1600 },
	health = 340, -- faction pass (S-62)
	movement = { maxSpeed = 36, accel = 30, brake = 50, turnRate = 180 },
	sensors = { sight = 300 },
	weapons = { { def = "ord_mg", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "scout",
	model = "ord_herald",
})
