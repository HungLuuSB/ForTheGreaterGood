--!strict
-- Skyguard: Order's amphibious anti-air bot (S-233, the BAR roster program's batch 2;
-- BAR's armaak). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "ord_skyguard",
	name = "Skyguard",
	description = "Amphibious anti-air bot. Long- and short-range heat-seeking missiles; walks the seafloor.",
	faction = "order",
	tier = 2,
	domain = "ground",
	moveClass = "AMPHIB_WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "ARMORED", "ANTIAIR" },
	armorClass = "ARMORED",
	cost = { supply = 470, power = 5600, buildTime = 12000 },
	health = 2000,
	movement = { maxSpeed = 21, accel = 29, brake = 38, turnRate = 360 },
	sensors = { sight = 170 },
	weapons = {
		{ def = "ord_skyguard_long", turretPiece = "torso", pitchPiece = "launcher", muzzle = "muzzle" },
		{ def = "ord_skyguard_short", turretPiece = "torso", pitchPiece = "launcher", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "launcher", "muzzle" },
	icon = "aa",
	model = "ord_skyguard",
})
