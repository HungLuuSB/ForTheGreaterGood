--!strict
-- Gargoyle: Chaos's heavy amphibious anti-air bot (S-233, the BAR roster program's batch 2;
-- BAR's coraak). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_gargoyle",
	name = "Gargoyle",
	description = "Heavy amphibious anti-air bot. Long-range heat-seeking missiles; walks the seafloor.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	moveClass = "AMPHIB_WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "ARMORED", "ANTIAIR" },
	armorClass = "ARMORED",
	cost = { supply = 590, power = 7100, buildTime = 15000 },
	health = 2900,
	movement = { maxSpeed = 15.4, accel = 22, brake = 28, turnRate = 300 },
	sensors = { sight = 170 },
	weapons = {
		{ def = "chs_gargoyle_sam", turretPiece = "torso", pitchPiece = "launcher", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "launcher", "muzzle" },
	icon = "aa",
	model = "chs_gargoyle",
})
