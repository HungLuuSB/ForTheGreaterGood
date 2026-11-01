--!strict
-- Monolith: Order's all-terrain heavy artillery walker (S-233, the BAR roster program's batch 2;
-- BAR's armvang). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "ord_monolith",
	name = "Monolith",
	description = "All-terrain heavy artillery walker. Climbs anything, then shells bases from very far.",
	faction = "order",
	tier = 3,
	domain = "ground",
	moveClass = "SPIDER",
	footprint = 3, -- (C's blockout)
	categories = { "GROUND", "ARMORED", "ARTILLERY" },
	armorClass = "ARMORED",
	cost = { supply = 1700, power = 24000, buildTime = 55000 },
	health = 9000,
	movement = { maxSpeed = 8, accel = 11, brake = 14, turnRate = 120 },
	sensors = { sight = 260 },
	weapons = {
		{ def = "ord_monolith_cannon", turretPiece = "torso", pitchPiece = "barrel", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "barrel", "muzzle" },
	icon = "artillery",
	model = "ord_monolith",
})
