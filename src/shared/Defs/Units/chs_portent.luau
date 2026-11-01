--!strict
-- Portent: Chaos's radar bot (S-233, the BAR roster program's batch 2;
-- BAR's corvoyr). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_portent",
	name = "Portent",
	description = "Radar bot. A mobile radar dish that keeps up with the army.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "LIGHT", "RADAR_EMITTER" },
	armorClass = "LIGHT",
	cost = { supply = 88, power = 1100, buildTime = 3100 },
	health = 340,
	movement = { maxSpeed = 16.8, accel = 24, brake = 30, turnRate = 400 },
	sensors = { sight = 360, radar = 400, radarError = 30, radarDrain = 3 },
	pieces = { "base", "torso" },
	icon = "radar",
	model = "chs_portent",
})
