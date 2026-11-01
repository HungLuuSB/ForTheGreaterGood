--!strict
-- Scaler: Order's all-terrain rocket spider (S-233, the BAR roster program's batch 2;
-- BAR's armsptk). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "ord_scaler",
	name = "Scaler",
	description = "All-terrain rocket spider. Climbs cliffs to rain guided rockets from above.",
	faction = "order",
	tier = 2,
	domain = "ground",
	moveClass = "SPIDER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	cost = { supply = 360, power = 4300, buildTime = 9000 },
	health = 1200,
	movement = { maxSpeed = 21, accel = 29, brake = 38, turnRate = 300 },
	sensors = { sight = 190 },
	weapons = {
		{ def = "ord_scaler_rockets", turretPiece = "torso", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "muzzle" },
	icon = "artillery",
	model = "ord_scaler",
})
