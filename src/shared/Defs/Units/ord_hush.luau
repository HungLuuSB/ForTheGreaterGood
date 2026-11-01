--!strict
-- Hush: Order's jammer bot (S-233, the BAR roster program's batch 2;
-- BAR's armaser). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "ord_hush",
	name = "Hush",
	description = "Jammer bot. Hides nearby friendly units from enemy radar.",
	faction = "order",
	tier = 2,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "LIGHT", "JAMMER" },
	armorClass = "LIGHT",
	cost = { supply = 70, power = 840, buildTime = 3800 },
	health = 300,
	movement = { maxSpeed = 15.4, accel = 22, brake = 28, turnRate = 400 },
	sensors = { sight = 170, jam = 300, jamDrain = 20 },
	pieces = { "base", "torso" },
	icon = "jammer",
	model = "ord_hush",
})
