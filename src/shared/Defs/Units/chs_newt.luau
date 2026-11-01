--!strict
-- Newt: Chaos's amphibious bot (S-233, the BAR roster program's batch 2;
-- BAR's coramph). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_newt",
	name = "Newt",
	description = "Amphibious bot. A laser on land, a torpedo under water; walks the seafloor.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	moveClass = "AMPHIB_WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	cost = { supply = 300, power = 5400, buildTime = 7800 },
	health = 2100,
	movement = { maxSpeed = 23.8, accel = 33, brake = 43, turnRate = 360 },
	sensors = { sight = 170, radar = 60, sonar = 60 },
	weapons = {
		{ def = "chs_newt_laser", turretPiece = "torso", muzzle = "muzzle" },
		{ def = "chs_newt_torpedo", turretPiece = "torso", muzzle = "muzzle2" },
	},
	pieces = { "base", "torso", "muzzle", "muzzle2" },
	icon = "tank_amphib",
	model = "chs_newt",
})
