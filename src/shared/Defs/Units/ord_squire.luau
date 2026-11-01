--!strict
-- Squire: Order's fast infantry bot (S-233, the BAR roster program's batch 2;
-- BAR's armpw). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "ord_squire",
	name = "Squire",
	description = "Fast infantry bot. Cheap, quick, rapid plasma guns: a raider in numbers.",
	faction = "order",
	tier = 1,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "LIGHT" },
	armorClass = "LIGHT",
	cost = { supply = 48, power = 530, buildTime = 1200 },
	health = 330,
	movement = { maxSpeed = 37.8, accel = 53, brake = 68, turnRate = 420 },
	sensors = { sight = 180 },
	weapons = {
		{ def = "ord_squire_guns", turretPiece = "torso", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "muzzle" },
	icon = "scout",
	model = "ord_squire",
})
