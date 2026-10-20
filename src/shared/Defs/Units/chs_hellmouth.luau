--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.2 "Self-propelled artillery", T1): radar-targetable.
return Templates.extend(Templates.TankT1, {
	id = "chs_hellmouth",
	name = "Hellmouth",
	description = "Self-propelled mortar. Heavy, inaccurate indirect fire; can shell radar contacts.",
	faction = "chaos",
	categories = { "GROUND", "ARMORED", "ARTILLERY" },
	cost = { supply = 160, power = 1600, buildTime = 4800 },
	health = 820,
	movement = { maxSpeed = 24, accel = 9, brake = 18, turnRate = 85 },
	sensors = { sight = 130 },
	weapons = { { def = "chs_mortar", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	model = "chs_hellmouth",
	icon = "artillery",
})
