--!strict
-- Ravener: Chaos's heavy all-terrain spider (S-233, the BAR roster program's batch 2;
-- BAR's cortermite). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_ravener",
	name = "Ravener",
	description = "Heavy all-terrain spider. Climbs cliffs and burns what it finds with a heat ray.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	moveClass = "SPIDER",
	footprint = 2, -- (C's blockout)
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	cost = { supply = 480, power = 5800, buildTime = 12000 },
	health = 2800,
	movement = { maxSpeed = 21, accel = 29, brake = 38, turnRate = 300 },
	sensors = { sight = 170 },
	weapons = {
		{ def = "chs_ravener_ray", turretPiece = "torso", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "muzzle" },
	icon = "tank_heavy",
	model = "chs_ravener",
})
