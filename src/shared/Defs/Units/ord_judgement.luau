--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.2 "MLRS", T2); stats to balance in M8.
return Templates.extend(Templates.TankT1, {
	id = "ord_judgement",
	name = "Judgement",
	description = "MLRS. Precise long-range rockets.",
	faction = "order",
	tier = 2,
	domain = "ground",
	categories = { "GROUND", "ARMORED", "ARTILLERY" },
	armorClass = "ARMORED",
	moveClass = "TRACKED",
	footprint = 1,
	cost = { supply = 260, power = 2800, buildTime = 7000 },
	health = 1000, -- faction pass (S-62)
	movement = { maxSpeed = 26, accel = 10, brake = 20, turnRate = 90 },
	sensors = { sight = 150 },
	weapons = { { def = "ord_mlrs", turretPiece = "launcher", muzzle = "muzzle" } },
	pieces = { "base", "launcher", "turret", "muzzle" },
	icon = "artillery",
	model = "ord_judgement",
})
