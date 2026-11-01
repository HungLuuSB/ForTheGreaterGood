--!strict
-- Petard: Order's rocket bot (S-233, the BAR roster program's batch 2;
-- BAR's armrock). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "ord_petard",
	name = "Petard",
	description = "Rocket bot. Slow guided rockets that out-range defence towers.",
	faction = "order",
	tier = 1,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "LIGHT" },
	armorClass = "LIGHT",
	cost = { supply = 110, power = 1200, buildTime = 2800 },
	health = 640,
	movement = { maxSpeed = 22.4, accel = 31, brake = 40, turnRate = 400 },
	sensors = { sight = 170 },
	weapons = {
		{ def = "ord_petard_rocket", turretPiece = "torso", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "muzzle" },
	icon = "artillery",
	model = "ord_petard",
})
