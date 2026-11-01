--!strict
-- Paragon: Order's amphibious assault mech (S-233, the BAR roster program's batch 2;
-- BAR's armmar). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "ord_paragon",
	name = "Paragon",
	description = "Amphibious assault mech. Fast for its size: twin gauss cannons and an anti-air missile.",
	faction = "order",
	tier = 3,
	domain = "ground",
	moveClass = "AMPHIB_WALKER",
	footprint = 2, -- (C's blockout)
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	cost = { supply = 900, power = 13000, buildTime = 30000 },
	health = 6000,
	movement = { maxSpeed = 24, accel = 34, brake = 43, turnRate = 200 },
	sensors = { sight = 200 },
	weapons = {
		{ def = "ord_paragon_gauss", turretPiece = "torso", muzzle = "muzzle" },
		{ def = "ord_paragon_sam", turretPiece = "torso", muzzle = "muzzle2" },
	},
	pieces = { "base", "torso", "muzzle", "muzzle2" },
	icon = "experimental",
	model = "ord_paragon",
})
