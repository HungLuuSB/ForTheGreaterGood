--!strict
-- Volley: Order's T1 hover rocket artillery (S-230, the BAR roster program's batch 1;
-- BAR's armmh). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "ord_volley",
	name = "Volley",
	description = "Hover rocket artillery. A barrage of unguided rockets from the water's edge.",
	faction = "order",
	tier = 1,
	domain = "ground",
	categories = { "GROUND", "ARTILLERY" },
	armorClass = "LIGHT",
	moveClass = "HOVER",
	footprint = 1, -- (C's blockout)
	cost = { supply = 120, power = 1200, buildTime = 3400 },
	health = 300,
	movement = { maxSpeed = 17, accel = 12, brake = 24, turnRate = 100 },
	sensors = { sight = 200 },
	weapons = { { def = "ord_volley_rockets", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "artillery",
	model = "ord_volley",
})
