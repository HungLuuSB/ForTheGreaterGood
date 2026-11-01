--!strict
-- Martyr: Order's rolling bomb (S-233, the BAR roster program's batch 2;
-- BAR's armvader). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "ord_martyr",
	name = "Martyr",
	description = "Rolling bomb. Amphibious; rolls into the enemy and explodes, also when destroyed.",
	faction = "order",
	tier = 2,
	domain = "ground",
	moveClass = "AMPHIB_WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "LIGHT" },
	armorClass = "LIGHT",
	cost = { supply = 59, power = 3300, buildTime = 5000 },
	health = 400,
	movement = { maxSpeed = 36.4, accel = 51, brake = 66, turnRate = 450 },
	sensors = { sight = 110 },
	selfDestructSeconds = 0, -- at once (S-233)
	deathBlast = { damage = 1100, aoe = 18, edge = 0.3 },
	selfDestructBlast = { damage = 1100, aoe = 18, edge = 0.3 },
	weapons = {
		{ def = "ord_martyr_trigger", turretPiece = "torso", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "muzzle" },
	icon = "scout",
	model = "ord_martyr",
})
