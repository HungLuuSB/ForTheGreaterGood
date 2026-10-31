--!strict
-- Halcyon: Order's T1 hover anti-air (S-230, the BAR roster program's batch 1;
-- BAR's armah). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "ord_halcyon",
	name = "Halcyon",
	description = "Hover anti-air. Missiles against aircraft, over land and water.",
	faction = "order",
	tier = 1,
	domain = "ground",
	categories = { "GROUND", "LIGHT", "ANTIAIR" },
	armorClass = "LIGHT",
	moveClass = "HOVER",
	footprint = 1, -- (C's blockout)
	cost = { supply = 160, power = 1800, buildTime = 4500 },
	health = 600,
	movement = { maxSpeed = 23, accel = 16, brake = 32, turnRate = 100 },
	sensors = { sight = 200 },
	weapons = { { def = "ord_halcyon_aa", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "aa",
	model = "ord_halcyon",
})
