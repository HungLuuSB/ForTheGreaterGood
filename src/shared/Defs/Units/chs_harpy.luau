--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.3); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_harpy",
	name = "Harpy",
	description = "Fighter. Fires swarms of missiles at aircraft.",
	faction = "chaos",
	tier = 1,
	domain = "air",
	categories = { "AIR", "JET" },
	armorClass = "AIR",
	moveClass = "JET",
	footprint = 1,
	cost = { supply = 130, power = 2700, buildTime = 5600 },
	health = 480, -- faction pass (S-62)
	movement = { maxSpeed = 162, minSpeed = 78, accel = 80, brake = 60, turnRate = 98 },
	sensors = { sight = 200, airSight = 380 },
	weapons = { { def = "chs_aam", turretPiece = "pylon", muzzle = "muzzle" } },
	rearmTime = 1.5,
	countermeasures = {
		flares = { charges = 6, chance = 0.55, refillSupply = 2 },
		chaff = { charges = 6, chance = 0.5, refillSupply = 3 },
	},
	pieces = { "base", "pylon", "muzzle" },
	model = "chs_harpy",
	icon = "fighter",
})
