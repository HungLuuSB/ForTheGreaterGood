--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.3 "Bomber", T1); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_plague",
	name = "Plague",
	description = "Bomber. Carpet-bombs ground targets.",
	faction = "chaos",
	tier = 1,
	domain = "air",
	categories = { "AIR", "JET" },
	armorClass = "AIR",
	moveClass = "JET",
	footprint = 1,
	cost = { supply = 190, power = 3300, buildTime = 6600 },
	health = 1000,
	movement = { maxSpeed = 114, minSpeed = 69, accel = 80, brake = 60, turnRate = 72 },
	sensors = { sight = 190 },
	weapons = { { def = "chs_bomb", muzzle = "muzzle" } },
	pieces = { "base", "bay", "pylon", "muzzle" },
	icon = "bomber",
	rearmTime = 1.6,
	countermeasures = { flares = { charges = 6, chance = 0.55, refillSupply = 2 } },
	model = "chs_plague",
})
