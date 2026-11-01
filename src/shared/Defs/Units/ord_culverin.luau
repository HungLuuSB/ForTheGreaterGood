--!strict
-- Culverin: Order's mortar bot (S-233, the BAR roster program's batch 2;
-- BAR's armfido). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "ord_culverin",
	name = "Culverin",
	description = "Mortar bot. Lobs plasma shells over walls and hills.",
	faction = "order",
	tier = 2,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	cost = { supply = 260, power = 3600, buildTime = 6500 },
	health = 1000,
	movement = { maxSpeed = 29.4, accel = 41, brake = 53, turnRate = 360 },
	sensors = { sight = 170 },
	weapons = {
		{ def = "ord_culverin_mortar", turretPiece = "torso", pitchPiece = "barrel", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "barrel", "muzzle" },
	icon = "artillery",
	model = "ord_culverin",
})
