--!strict
-- Skimmer: Order's T1 hover tank (S-230, the BAR roster program's batch 1;
-- BAR's armanac). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "ord_skimmer",
	name = "Skimmer",
	description = "Hover tank. A plasma gun on a hull that crosses land and water.",
	faction = "order",
	tier = 1,
	domain = "ground",
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	moveClass = "HOVER",
	footprint = 1, -- (C's blockout)
	cost = { supply = 190, power = 1900, buildTime = 5300 },
	health = 840,
	movement = { maxSpeed = 19, accel = 13, brake = 27, turnRate = 100 },
	sensors = { sight = 200 },
	weapons = { { def = "ord_skimmer_gun", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	pieces = { "base", "turret", "barrel", "muzzle" },
	icon = "tank_light",
	model = "ord_skimmer",
})
