--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.4 "EW ship", T2); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_siren",
	name = "Siren",
	description = "Naval jammer. Hides friendly ships and coast from enemy radar.",
	faction = "chaos",
	tier = 2,
	domain = "naval",
	categories = { "NAVAL", "JAMMER" },
	armorClass = "SHIP",
	moveClass = "SHIP",
	footprint = 1,
	cost = { supply = 300, power = 4200, buildTime = 8000 },
	health = 1600,
	movement = { maxSpeed = 26, accel = 8, brake = 12, turnRate = 55 },
	sensors = { sight = 220, jam = 520 },
	weapons = {},
	pieces = { "base", "turret1", "turret2", "muzzle1", "muzzle2" },
	icon = "ew_ship",
	model = "chs_siren",
})
