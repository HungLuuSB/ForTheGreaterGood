--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.3 "Strategic bomber", T2); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_behemoth",
	name = "Behemoth",
	description = "Strategic bomber. Armored, chaff.",
	faction = "chaos",
	tier = 2,
	domain = "air",
	categories = { "AIR", "JET" },
	armorClass = "AIR",
	moveClass = "JET",
	footprint = 1,
	cost = { supply = 480, power = 8000, buildTime = 14000 },
	health = 2600,
	movement = { maxSpeed = 114, minSpeed = 72, accel = 80, brake = 60, turnRate = 52 },
	sensors = { sight = 190 },
	weapons = { { def = "chs_heavy_bomb", muzzle = "muzzle" } },
	pieces = { "base", "bay", "pylon", "muzzle" },
	icon = "bomber_heavy",
	ammo = 3,
	ammoCost = { supply = 35, power = 260 },
	rearmTime = 3.5,
	countermeasures = { chaff = { charges = 8, chance = 0.5, refillSupply = 3 } },
	model = "chs_behemoth",
})
