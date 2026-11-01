--!strict
-- Pyre: Chaos's fast flamethrower bot (S-233, the BAR roster program's batch 2;
-- BAR's corpyro). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_pyre",
	name = "Pyre",
	description = "Fast flamethrower bot. Burns through groups of light units up close.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	cost = { supply = 180, power = 2200, buildTime = 4500 },
	health = 940,
	movement = { maxSpeed = 36.4, accel = 51, brake = 66, turnRate = 420 },
	sensors = { sight = 170 },
	weapons = {
		{ def = "chs_pyre_flame", turretPiece = "torso", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "muzzle" },
	icon = "tank_light",
	model = "chs_pyre",
})
