--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.4); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "ord_sentry",
	name = "Envoy", -- (S-157, the user: "Sentry" went to the laser tower)
	description = "Corvette. Fast and cheap; light gun.",
	faction = "order",
	tier = 1,
	domain = "naval",
	categories = { "NAVAL" },
	armorClass = "SHIP",
	moveClass = "SHIP",
	footprint = 1,
	cost = { supply = 120, power = 1000, buildTime = 3200 },
	health = 900,
	movement = { maxSpeed = 34, accel = 10, brake = 14, turnRate = 70 },
	sensors = { sight = 220 },
	weapons = { { def = "ord_naval_gun", turretPiece = "turret1", muzzle = "muzzle1" } },
	pieces = { "base", "turret1", "turret2", "muzzle1", "muzzle2" },
	model = "ord_sentry",
	icon = "corvette",
})
