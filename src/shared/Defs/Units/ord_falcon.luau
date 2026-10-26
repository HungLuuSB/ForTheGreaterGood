--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.3); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "ord_falcon",
	name = "Falcon",
	description = "Fighter. Intercepts aircraft with a few precise missiles.",
	faction = "order",
	tier = 1,
	domain = "air",
	categories = { "AIR", "JET" },
	armorClass = "AIR",
	moveClass = "JET",
	footprint = 1,
	cost = { supply = 160, power = 3100, buildTime = 5900 },
	health = 660, -- faction pass, tuned (S-62)
	movement = { maxSpeed = 144, minSpeed = 84, accel = 90, brake = 70, turnRate = 112 },
	sensors = { sight = 220, airSight = 420 },
	weapons = { { def = "ord_aam", turretPiece = "pylon", muzzle = "muzzle" } },
	rearmTime = 2,
	countermeasures = { chaff = { charges = 2, chance = 0.5, refillSupply = 3 }, dircm = { chance = 0.7, cooldown = 3, powerDrain = 15 } },
	pieces = { "base", "pylon", "muzzle" },
	model = "ord_falcon",
	icon = "fighter",
})
