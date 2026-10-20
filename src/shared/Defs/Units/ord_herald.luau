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
	cost = { supply = 50, power = 600, buildTime = 1500 },
	health = 300,
	movement = { maxSpeed = 70, accel = 30, brake = 50, turnRate = 180 },
	sensors = { sight = 280 },
	weapons = { { def = "ord_mg", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "scout",
	model = "ord_herald",
})
