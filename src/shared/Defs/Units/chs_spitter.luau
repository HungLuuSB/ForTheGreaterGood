--!strict
-- Spitter: Chaos's mortar bot (S-233, the BAR roster program's batch 2;
-- BAR's cormort). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_spitter",
	name = "Spitter",
	description = "Mortar bot. Lobs plasma shells over walls and hills.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "LIGHT" },
	armorClass = "LIGHT",
	cost = { supply = 360, power = 4300, buildTime = 9000 },
	health = 840,
	movement = { maxSpeed = 21, accel = 29, brake = 38, turnRate = 360 },
	sensors = { sight = 170 },
	weapons = {
		{ def = "chs_spitter_mortar", turretPiece = "torso", pitchPiece = "barrel", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "barrel", "muzzle" },
	icon = "artillery",
	model = "chs_spitter",
})
