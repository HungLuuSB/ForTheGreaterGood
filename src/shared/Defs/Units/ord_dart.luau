--!strict
-- Dart: Order's T1 fast hover raider (S-230, the BAR roster program's batch 1;
-- BAR's armsh). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "ord_dart",
	name = "Dart",
	description = "Fast hover raider. A machine gun on the quickest hull on land or water.",
	faction = "order",
	tier = 1,
	domain = "ground",
	categories = { "GROUND", "LIGHT" },
	armorClass = "LIGHT",
	moveClass = "HOVER",
	footprint = 1, -- (C's blockout)
	cost = { supply = 59, power = 600, buildTime = 1650 },
	health = 160,
	movement = { maxSpeed = 30, accel = 21, brake = 42, turnRate = 130 },
	sensors = { sight = 210 },
	weapons = { { def = "ord_dart_mg", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "scout",
	model = "ord_dart",
})
