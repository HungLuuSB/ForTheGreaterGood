--!strict
-- Blister: Chaos's crawling bomb (S-233, the BAR roster program's batch 2;
-- BAR's corroach). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_blister",
	name = "Blister",
	description = "Crawling bomb. Amphibious; crawls into the enemy and explodes, also when destroyed.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	moveClass = "AMPHIB_WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "LIGHT" },
	armorClass = "LIGHT",
	cost = { supply = 62, power = 3300, buildTime = 5000 },
	health = 550,
	movement = { maxSpeed = 33.6, accel = 47, brake = 60, turnRate = 450 },
	sensors = { sight = 110 },
	selfDestructSeconds = 0, -- at once (S-233)
	deathBlast = { damage = 1100, aoe = 18, edge = 0.3 },
	selfDestructBlast = { damage = 1100, aoe = 18, edge = 0.3 },
	weapons = {
		{ def = "chs_blister_trigger", turretPiece = "torso", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "muzzle" },
	icon = "scout",
	model = "chs_blister",
})
