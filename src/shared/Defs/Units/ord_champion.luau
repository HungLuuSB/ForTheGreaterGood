--!strict
-- Champion: Order's battle mech (S-233, the BAR roster program's batch 2;
-- BAR's armraz). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "ord_champion",
	name = "Champion",
	description = "Battle mech. A rapid armour-piercing laser that shreds anything in front of it.",
	faction = "order",
	tier = 3,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 3, -- (C's blockout)
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	cost = { supply = 1800, power = 26000, buildTime = 60000 },
	health = 14000,
	movement = { maxSpeed = 14, accel = 20, brake = 25, turnRate = 160 },
	sensors = { sight = 200 },
	weapons = {
		{ def = "ord_champion_laser", turretPiece = "torso", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "muzzle" },
	icon = "experimental",
	model = "ord_champion",
})
