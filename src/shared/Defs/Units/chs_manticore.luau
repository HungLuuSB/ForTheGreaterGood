--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.3 "Air superiority fighter", T2); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_manticore",
	name = "Manticore",
	description = "Air superiority fighter. Heavy missiles and flares.",
	faction = "chaos",
	tier = 2,
	domain = "air",
	categories = { "AIR", "JET" },
	armorClass = "AIR",
	moveClass = "JET",
	footprint = 1,
	cost = { supply = 305, power = 5750, buildTime = 9300 },
	health = 880, -- faction pass, tuned (S-62)
	movement = { maxSpeed = 186, minSpeed = 90, accel = 80, brake = 60, turnRate = 112 },
	sensors = { sight = 220, airSight = 440 },
	weapons = { { def = "chs_heavy_aam", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "pylon", "muzzle" },
	icon = "fighter",
	rearmTime = 1.4,
	countermeasures = { flares = { charges = 12, chance = 0.55, refillSupply = 2 } },
	model = "chs_manticore",
})
