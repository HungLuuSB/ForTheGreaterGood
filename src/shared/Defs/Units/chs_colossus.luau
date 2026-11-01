--!strict
-- Colossus: Chaos's walking fortress (S-233, the BAR roster program's batch 2;
-- BAR's corjugg). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233). (S-236, the
-- user's FTGG-FEEDBACK-5) A barely mobile heavy turret that takes on a whole
-- army alone: bigger, 3× the health, half the speed, and its main cannon
-- fires the D-Gun's bolt (9000 to everything on its path, every 2 s).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_colossus",
	name = "Colossus",
	description = "Walking fortress. Barely moves, almost unkillable: three lasers and a D-Gun cannon that cuts through lines of units.",
	faction = "chaos",
	tier = 3,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 5, -- bigger (S-236, the user; was 4)
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	cost = { supply = 5000, power = 72000, buildTime = 170000 },
	health = 240000, -- 3× (S-236, the user; was 80000)
	movement = { maxSpeed = 1.5, accel = 2.1, brake = 6, turnRate = 30 }, -- half (S-236, the user; was 3)
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
