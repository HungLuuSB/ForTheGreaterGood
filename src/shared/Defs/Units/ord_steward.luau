--!strict
-- Steward: Order's fast assist and repair bot (S-233, the BAR roster program's batch 2;
-- BAR's armfark). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "ord_steward",
	name = "Steward",
	description = "Fast assist and repair bot. Speeds up building and mends units; builds nothing itself.",
	faction = "order",
	tier = 2,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "WORKER" },
	armorClass = "LIGHT",
	cost = { supply = 180, power = 2200, buildTime = 4500 },
	health = 290,
	movement = { maxSpeed = 32.2, accel = 45, brake = 58, turnRate = 420 },
	sensors = { sight = 170 },
	buildPower = 120,
	buildRange = 45,
	assistOnly = true, -- repairs, assists and reclaims; builds nothing
	pieces = { "base", "torso", "nano", "nano1" },
	icon = "worker",
	model = "ord_steward",
})
