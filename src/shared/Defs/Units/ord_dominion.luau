--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.4 "Cruiser / battleship", T2); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "ord_dominion",
	name = "Dominion",
	description = "Cruiser. Heavy guns and flak.",
	faction = "order",
	tier = 2,
	domain = "naval",
	categories = { "NAVAL" },
	armorClass = "SHIP",
	moveClass = "SHIP",
	footprint = 3,
	cost = { supply = 800, power = 9000, buildTime = 18000 },
	health = 5200,
	movement = { maxSpeed = 12, accel = 5, brake = 8, turnRate = 35 },
	sensors = { sight = 280, radar = 450, radarError = 20 },
	weapons = { { def = "ord_heavy_naval_gun", turretPiece = "turret1", muzzle = "muzzle1" }, { def = "ord_flak", turretPiece = "turret2", muzzle = "muzzle2" } },
	pieces = { "base", "turret1", "turret2", "muzzle1", "muzzle2" },
	icon = "cruiser",
	model = "ord_dominion",
})
