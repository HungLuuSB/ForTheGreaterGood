--!strict
-- Tempest: Order's T3 heavy hovertank from the gantry (S-230, the BAR roster program's batch 1;
-- BAR's armlun). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "ord_tempest",
	name = "Tempest",
	description = "Heavy hovertank. A heavy gun on an armored hull that crosses land and water.",
	faction = "order",
	tier = 3,
	domain = "ground",
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	moveClass = "HOVER",
	footprint = 3, -- (C's blockout)
	cost = { supply = 790, power = 10000, buildTime = 20000 },
	health = 4250,
	movement = { maxSpeed = 14, accel = 10, brake = 20, turnRate = 80 },
	sensors = { sight = 240 },
	weapons = { { def = "ord_tempest_gun", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	pieces = { "base", "turret", "barrel", "muzzle" },
	icon = "tank_heavy",
	model = "ord_tempest",
})
