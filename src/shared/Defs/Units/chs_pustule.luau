--!strict
-- Pustule: Chaos's cloaked crawling bomb (S-233, the BAR roster program's batch 2;
-- BAR's corsktl). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_pustule",
	name = "Pustule",
	description = "Cloaked crawling bomb. Creeps unseen into a base, then one huge blast; also when destroyed.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	moveClass = "AMPHIB_WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "LIGHT", "STEALTH" },
	armorClass = "LIGHT",
	cost = { supply = 680, power = 15000, buildTime = 17000 },
	health = 310,
	movement = { maxSpeed = 36.4, accel = 51, brake = 66, turnRate = 450 },
	sensors = { sight = 110 },
	cloak = { drain = 6, decloak = 21 },
	selfDestructSeconds = 0, -- at once (S-233)
	deathBlast = { damage = 4000, aoe = 45, edge = 0.3 },
	selfDestructBlast = { damage = 4000, aoe = 45, edge = 0.3 },
	weapons = {
		{ def = "chs_pustule_trigger", turretPiece = "torso", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "muzzle" },
	icon = "scout",
	model = "chs_pustule",
})
