--!strict
-- Pandemonium: Chaos's heavy rocket mech (S-233, the BAR roster program's batch 2;
-- BAR's corcat). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_pandemonium",
	name = "Pandemonium",
	description = "Heavy rocket mech. Empties a rack of guided rockets over a wide area, then reloads for long.",
	faction = "chaos",
	tier = 3,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 3, -- (C's blockout)
	categories = { "GROUND", "ARMORED", "ARTILLERY" },
	armorClass = "ARMORED",
	cost = { supply = 2200, power = 30000, buildTime = 70000 },
	health = 7500,
	movement = { maxSpeed = 12, accel = 17, brake = 22, turnRate = 160 },
	sensors = { sight = 280 },
	weapons = {
		{ def = "chs_pandemonium_rockets", turretPiece = "torso", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "muzzle", "muzzle2" },
	icon = "experimental",
	model = "chs_pandemonium",
})
