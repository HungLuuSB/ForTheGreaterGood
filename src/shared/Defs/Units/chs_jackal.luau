--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.2 "Scout", T1); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_jackal",
	name = "Jackal",
	description = "Scout. A fast vehicle with wide sight and a light gun.",
	faction = "chaos",
	tier = 1,
	domain = "ground",
	categories = { "GROUND", "LIGHT" },
	armorClass = "LIGHT",
	moveClass = "WHEELED",
	footprint = 1,
	cost = { supply = 45, power = 540, buildTime = 1400 },
	health = 280, -- faction pass (S-62)
	movement = { maxSpeed = 45.6, accel = 30, brake = 50, turnRate = 180 },
	sensors = { sight = 220 },
	weapons = { { def = "chs_mg", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "scout",
	model = "chs_jackal",
})
