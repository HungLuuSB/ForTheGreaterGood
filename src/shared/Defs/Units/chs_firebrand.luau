--!strict
-- Firebrand: Chaos's rocket bot (S-233, the BAR roster program's batch 2;
-- BAR's corstorm). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_firebrand",
	name = "Firebrand",
	description = "Rocket bot. Slow guided rockets that out-range defence towers.",
	faction = "chaos",
	tier = 1,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "LIGHT" },
	armorClass = "LIGHT",
	cost = { supply = 99, power = 1100, buildTime = 2500 },
	health = 660,
	movement = { maxSpeed = 21, accel = 29, brake = 38, turnRate = 400 },
	sensors = { sight = 170 },
	weapons = {
		{ def = "chs_firebrand_rocket", turretPiece = "torso", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "muzzle" },
	icon = "artillery",
	model = "chs_firebrand",
})
