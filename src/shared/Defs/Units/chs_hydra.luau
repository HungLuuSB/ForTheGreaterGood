--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.2 "MLRS", T2); stats to balance in M8.
return Templates.extend(Templates.TankT1, {
	id = "chs_hydra",
	name = "Hydra",
	description = "MLRS. Large inaccurate salvos.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	categories = { "GROUND", "ARMORED", "ARTILLERY" },
	armorClass = "ARMORED",
	moveClass = "TRACKED",
	footprint = 1,
	cost = { supply = 260, power = 2800, buildTime = 7000 },
	health = 1000,
	movement = { maxSpeed = 28, accel = 10, brake = 20, turnRate = 90 },
	sensors = { sight = 150 },
	weapons = { { def = "chs_mlrs", turretPiece = "launcher", muzzle = "muzzle" } },
	pieces = { "base", "launcher", "turret", "muzzle" },
	icon = "artillery",
	model = "chs_hydra",
})
