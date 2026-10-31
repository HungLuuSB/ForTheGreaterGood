--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.4); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_barracuda",
	name = "Piranha", -- Barracuda until S-225: BAR's Barracuda is a different unit
	description = "Corvette. A small fast ship with a light gun.",
	faction = "chaos",
	tier = 1,
	domain = "naval",
	categories = { "NAVAL" },
	armorClass = "SHIP",
	moveClass = "SHIP",
	footprint = 1,
	cost = { supply = 110, power = 900, buildTime = 3000 },
	health = 980,
	movement = { maxSpeed = 19.2, accel = 10, brake = 14, turnRate = 65 },
	sensors = { sight = 200 },
	weapons = { { def = "chs_barracuda_gun", turretPiece = "turret1", muzzle = "muzzle1" } },
	pieces = { "base", "turret1", "turret2", "muzzle1", "muzzle2" },
	model = "chs_barracuda",
	icon = "corvette",
})
