--!strict
-- Mariner: Order's amphibious bot (S-233, the BAR roster program's batch 2;
-- BAR's armamph). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "ord_mariner",
	name = "Mariner",
	description = "Amphibious bot. A light laser and an anti-air missile; walks the seafloor.",
	faction = "order",
	tier = 2,
	domain = "ground",
	moveClass = "AMPHIB_WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	cost = { supply = 230, power = 2800, buildTime = 5800 },
	health = 1000,
	movement = { maxSpeed = 39.2, accel = 55, brake = 71, turnRate = 360 },
	sensors = { sight = 170 },
	weapons = {
		{ def = "ord_mariner_laser", turretPiece = "torso", muzzle = "muzzle" },
		{ def = "ord_mariner_sam", turretPiece = "torso", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "muzzle" },
	icon = "tank_amphib",
	model = "ord_mariner",
})
