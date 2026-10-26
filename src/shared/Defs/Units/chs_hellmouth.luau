--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.2 "Self-propelled artillery", T1): radar-targetable.
return Templates.extend(Templates.TankT1, {
	id = "chs_hellmouth",
	name = "Hellmouth",
	description = "Self-propelled mortar. Heavy, inaccurate indirect fire; can shell radar contacts.",
	faction = "chaos",
	categories = { "GROUND", "ARMORED", "ARTILLERY" },
	cost = { supply = 175, power = 1750, buildTime = 4800 },
	health = 570, -- tier rebalance (S-157, the user): was 700; faction pass (S-62)
	movement = { maxSpeed = 16.8, accel = 9, brake = 18, turnRate = 85 },
	sensors = { sight = 130 },
	weapons = { { def = "chs_mortar", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	model = "chs_hellmouth",
	icon = "artillery",
})
