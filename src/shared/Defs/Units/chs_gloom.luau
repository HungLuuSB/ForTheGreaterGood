--!strict
-- Gloom: Chaos's jammer bot (S-233, the BAR roster program's batch 2;
-- BAR's corspec). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_gloom",
	name = "Gloom",
	description = "Jammer bot. Hides nearby friendly units from enemy radar.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "LIGHT", "JAMMER" },
	armorClass = "LIGHT",
	cost = { supply = 68, power = 820, buildTime = 4100 },
	health = 310,
	movement = { maxSpeed = 15.4, accel = 22, brake = 28, turnRate = 400 },
	sensors = { sight = 170, jam = 300, jamDrain = 20 },
	pieces = { "base", "torso" },
	icon = "jammer",
	model = "chs_gloom",
})
