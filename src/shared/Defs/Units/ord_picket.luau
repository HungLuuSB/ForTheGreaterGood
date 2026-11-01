--!strict
-- Picket: Order's anti-swarm bot (S-233, the BAR roster program's batch 2;
-- BAR's armwar). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "ord_picket",
	name = "Picket",
	description = "Anti-swarm bot. Twin close lasers that cut light units down fast.",
	faction = "order",
	tier = 1,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	cost = { supply = 250, power = 2800, buildTime = 6300 },
	health = 1400,
	movement = { maxSpeed = 19.6, accel = 27, brake = 35, turnRate = 360 },
	sensors = { sight = 170 },
	weapons = {
		{ def = "ord_picket_laser", turretPiece = "torso", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "muzzle", "muzzle2" },
	icon = "tank_heavy",
	model = "ord_picket",
})
