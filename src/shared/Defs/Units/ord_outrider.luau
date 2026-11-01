--!strict
-- Outrider: Order's fast raider bot (S-233, the BAR roster program's batch 2;
-- BAR's armfast). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "ord_outrider",
	name = "Outrider",
	description = "Fast raider bot. The quickest walker: rapid plasma guns to hunt workers and extractors.",
	faction = "order",
	tier = 2,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "LIGHT" },
	armorClass = "LIGHT",
	cost = { supply = 140, power = 2200, buildTime = 3500 },
	health = 620,
	movement = { maxSpeed = 47.6, accel = 67, brake = 86, turnRate = 450 },
	sensors = { sight = 170 },
	weapons = {
		{ def = "ord_outrider_guns", turretPiece = "torso", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "muzzle", "muzzle2" },
	icon = "scout",
	model = "ord_outrider",
})
