--!strict
-- Marksman: Order's cloaked sniper bot (S-233, the BAR roster program's batch 2;
-- BAR's armsnipe). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "ord_marksman",
	name = "Marksman",
	description = "Cloaked sniper bot. One huge shot every 13 s from far away; unseen while it waits.",
	faction = "order",
	tier = 2,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "LIGHT", "STEALTH" },
	armorClass = "LIGHT",
	cost = { supply = 610, power = 11000, buildTime = 15000 },
	health = 510,
	movement = { maxSpeed = 14, accel = 20, brake = 25, turnRate = 300 },
	sensors = { sight = 200 },
	cloak = { drain = 25, decloak = 30 },
	weapons = {
		{ def = "ord_marksman_rifle", turretPiece = "torso", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "muzzle" },
	icon = "artillery",
	model = "ord_marksman",
})
