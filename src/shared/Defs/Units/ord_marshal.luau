--!strict
-- Marshal: Order's skirmisher bot (S-233, the BAR roster program's batch 2;
-- BAR's armmav). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "ord_marshal",
	name = "Marshal",
	description = "Skirmisher bot. Gauss guns that hit hard from just outside a raider's reach.",
	faction = "order",
	tier = 2,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	cost = { supply = 590, power = 7100, buildTime = 15000 },
	health = 1600,
	movement = { maxSpeed = 21, accel = 29, brake = 38, turnRate = 300 },
	sensors = { sight = 230 },
	weapons = {
		{ def = "ord_marshal_gauss", turretPiece = "torso", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "muzzle", "muzzle2" },
	icon = "tank_heavy",
	model = "ord_marshal",
})
