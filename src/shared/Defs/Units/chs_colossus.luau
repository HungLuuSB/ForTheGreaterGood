--!strict
-- Colossus: Chaos's walking fortress (S-233, the BAR roster program's batch 2;
-- BAR's corjugg). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_colossus",
	name = "Colossus",
	description = "Walking fortress. Barely moves, almost unkillable: three lasers and a plasma cannon.",
	faction = "chaos",
	tier = 3,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 4, -- (C's blockout)
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	cost = { supply = 5000, power = 72000, buildTime = 170000 },
	health = 80000,
	movement = { maxSpeed = 3, accel = 4.2, brake = 6, turnRate = 30 },
	sensors = { sight = 300 },
	weapons = {
		{ def = "chs_colossus_fire", turretPiece = "torso", muzzle = "muzzle" },
		{ def = "chs_colossus_laser", turretPiece = "torso", muzzle = "muzzle2" },
		{ def = "chs_colossus_toplaser", turretPiece = "torso", muzzle = "muzzle3" },
	},
	pieces = { "base", "torso", "muzzle", "muzzle2", "muzzle3" },
	icon = "experimental",
	model = "chs_colossus",
})
