--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.2 "Self-propelled artillery", T1): radar-targetable.
return Templates.extend(Templates.TankT1, {
	id = "ord_verdict",
	name = "Verdict",
	description = "Self-propelled artillery. Long, precise indirect fire; can shell radar contacts.",
	faction = "order",
	categories = { "GROUND", "ARMORED", "ARTILLERY" },
	cost = { supply = 180, power = 1800, buildTime = 5200 },
	health = 700,
	movement = { maxSpeed = 26, accel = 10, brake = 20, turnRate = 90 },
	sensors = { sight = 140 },
	weapons = { { def = "ord_howitzer", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	model = "ord_verdict",
	icon = "artillery",
})
