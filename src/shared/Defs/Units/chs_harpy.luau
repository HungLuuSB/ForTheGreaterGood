--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.3); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_harpy",
	name = "Harpy",
	description = "Fighter. Many cheap missiles, less agile.",
	faction = "chaos",
	tier = 1,
	domain = "air",
	categories = { "AIR", "JET" },
	armorClass = "AIR",
	moveClass = "JET",
	footprint = 1,
	cost = { supply = 130, power = 2700, buildTime = 5600 },
	health = 480, -- faction pass (S-62)
	movement = { maxSpeed = 270, minSpeed = 130, accel = 80, brake = 60, turnRate = 65 },
	sensors = { sight = 200, airSight = 380 },
	weapons = { { def = "chs_aam", turretPiece = "pylon", muzzle = "muzzle" } },
	ammo = 6,
	ammoCost = { supply = 8, power = 110 },
	rearmTime = 1.5,
	countermeasures = {
		flares = { charges = 6, chance = 0.55, refillSupply = 2 },
		chaff = { charges = 6, chance = 0.5, refillSupply = 3 },
	},
	pieces = { "base", "pylon", "muzzle" },
	model = "chs_harpy",
	icon = "fighter",
})
