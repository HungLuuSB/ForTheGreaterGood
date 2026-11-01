--!strict
-- Stormcaller: Order's assault bot (S-233, the BAR roster program's batch 2;
-- BAR's armzeus). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "ord_stormcaller",
	name = "Stormcaller",
	description = "Assault bot. Heavily armoured, with a lightning rifle that chains through a crowd.",
	faction = "order",
	tier = 2,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	cost = { supply = 310, power = 3700, buildTime = 7800 },
	health = 3100,
	movement = { maxSpeed = 21, accel = 29, brake = 38, turnRate = 300 },
	sensors = { sight = 170 },
	weapons = {
		{ def = "ord_stormcaller_lightning", turretPiece = "torso", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "muzzle" },
	icon = "tank_heavy",
	model = "ord_stormcaller",
})
