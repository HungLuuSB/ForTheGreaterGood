--!strict
-- Informant: Order's spy bot (S-233, the BAR roster program's batch 2;
-- BAR's armspy). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "ord_informant",
	name = "Informant",
	description = "Spy bot. Cloaked and invisible to radar; self-destructs in an EMP burst that stuns everything near.",
	faction = "order",
	tier = 2,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "LIGHT", "STEALTH" },
	armorClass = "LIGHT",
	cost = { supply = 120, power = 5100, buildTime = 7500 },
	health = 270,
	movement = { maxSpeed = 28, accel = 39, brake = 50, turnRate = 420 },
	sensors = { sight = 230, radarSignature = 0 },
	cloak = { drain = 6, decloak = 25 },
	selfDestructSeconds = 0, -- at once (S-233)
	selfDestructBlast = { damage = 3000, aoe = 30, edge = 0.5, paralyzer = true },
	pieces = { "base", "torso" },
	icon = "scout",
	model = "ord_informant",
})
