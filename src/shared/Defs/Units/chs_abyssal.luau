--!strict
-- Abyssal: Chaos's amphibious siege mech (S-233, the BAR roster program's batch 2;
-- BAR's corshiva). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_abyssal",
	name = "Abyssal",
	description = "Amphibious siege mech. A heavy cannon and artillery rockets; walks the seafloor.",
	faction = "chaos",
	tier = 3,
	domain = "ground",
	moveClass = "AMPHIB_WALKER",
	footprint = 3, -- (C's blockout)
	categories = { "GROUND", "ARMORED", "ARTILLERY" },
	armorClass = "ARMORED",
	cost = { supply = 1300, power = 17000, buildTime = 36000 },
	health = 9500,
	movement = { maxSpeed = 11, accel = 15, brake = 20, turnRate = 160 },
	sensors = { sight = 220 },
	weapons = {
		{ def = "chs_abyssal_cannon", turretPiece = "torso", muzzle = "muzzle" },
		{ def = "chs_abyssal_rockets", turretPiece = "torso", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "muzzle" },
	icon = "experimental",
	model = "chs_abyssal",
})
