--!strict
-- Wrath: Chaos's heavy rocket artillery bot (S-233, the BAR roster program's batch 2;
-- BAR's corhrk). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_wrath",
	name = "Wrath",
	description = "Heavy rocket artillery bot. Big rockets on high arcs from long range; weak up close.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "LIGHT", "ARTILLERY" },
	armorClass = "LIGHT",
	cost = { supply = 530, power = 6400, buildTime = 13000 },
	health = 540,
	movement = { maxSpeed = 23.8, accel = 33, brake = 43, turnRate = 300 },
	sensors = { sight = 170 },
	weapons = {
		{ def = "chs_wrath_rocket", turretPiece = "torso", pitchPiece = "launcher", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "launcher", "muzzle" },
	icon = "artillery",
	model = "chs_wrath",
})
