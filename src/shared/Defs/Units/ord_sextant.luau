--!strict
-- Sextant: Order's radar bot (S-233, the BAR roster program's batch 2;
-- BAR's armmark). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "ord_sextant",
	name = "Sextant",
	description = "Radar bot. A mobile radar dish that keeps up with the army.",
	faction = "order",
	tier = 2,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "LIGHT", "RADAR_EMITTER" },
	armorClass = "LIGHT",
	cost = { supply = 90, power = 1100, buildTime = 3100 },
	health = 310,
	movement = { maxSpeed = 18.2, accel = 25, brake = 33, turnRate = 400 },
	sensors = { sight = 350, radar = 400, radarError = 16, radarDrain = 3 },
	pieces = { "base", "torso" },
	icon = "radar",
	model = "ord_sextant",
})
