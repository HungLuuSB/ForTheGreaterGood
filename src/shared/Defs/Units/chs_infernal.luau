--!strict
-- Infernal: Chaos's flamethrower mech (S-233, the BAR roster program's batch 2;
-- BAR's cordemon). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_infernal",
	name = "Infernal",
	description = "Flamethrower mech. A torrent of fire for anything near, and shoulder rockets for aircraft.",
	faction = "chaos",
	tier = 3,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 3, -- (C's blockout)
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	cost = { supply = 2600, power = 36000, buildTime = 80000 },
	health = 20000,
	movement = { maxSpeed = 14, accel = 20, brake = 25, turnRate = 160 },
	sensors = { sight = 200 },
	weapons = {
		{ def = "chs_infernal_flame", turretPiece = "torso", muzzle = "muzzle" },
		{ def = "chs_infernal_sam", turretPiece = "torso", muzzle = "aa_muzzle" },
	},
	pieces = { "base", "torso", "muzzle", "muzzle2", "aa_muzzle" },
	icon = "experimental",
	model = "chs_infernal",
})
