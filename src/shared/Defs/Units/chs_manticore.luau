--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.3 "Air superiority fighter", T2); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_manticore",
	name = "Manticore",
	description = "Air superiority fighter. Heavy missiles, many flares.",
	faction = "chaos",
	tier = 2,
	domain = "air",
	categories = { "AIR", "JET" },
	armorClass = "AIR",
	moveClass = "JET",
	footprint = 1,
	cost = { supply = 330, power = 6200, buildTime = 10000 },
	health = 950,
	movement = { maxSpeed = 280, minSpeed = 150, accel = 80, brake = 60, turnRate = 75 },
	sensors = { sight = 220, airSight = 440 },
	weapons = { { def = "chs_heavy_aam", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "pylon", "muzzle" },
	icon = "fighter",
	ammo = 10,
	ammoCost = { supply = 10, power = 140 },
	rearmTime = 1.4,
	countermeasures = { flares = { charges = 12, chance = 0.55, refillSupply = 2 } },
	model = "chs_manticore",
})
