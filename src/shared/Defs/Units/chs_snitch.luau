--!strict
-- Snitch: Chaos's spy bot (S-233, the BAR roster program's batch 2;
-- BAR's corspy). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_snitch",
	name = "Snitch",
	description = "Spy bot. Cloaked and invisible to radar; self-destructs in an EMP burst that stuns everything near.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "LIGHT", "STEALTH" },
	armorClass = "LIGHT",
	cost = { supply = 130, power = 5100, buildTime = 7500 },
	health = 400,
	movement = { maxSpeed = 26.6, accel = 37, brake = 48, turnRate = 420 },
	sensors = { sight = 230, radarSignature = 0 },
	cloak = { drain = 6, decloak = 25 },
	selfDestructSeconds = 0, -- at once (S-233)
	selfDestructBlast = { damage = 3000, aoe = 30, edge = 0.5, paralyzer = true },
	pieces = { "base", "torso" },
	icon = "scout",
	model = "chs_snitch",
})
