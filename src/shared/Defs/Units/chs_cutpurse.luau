--!strict
-- Cutpurse: Chaos's combat engineer (S-233, the BAR roster program's batch 2;
-- BAR's cormando). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "chs_cutpurse",
	name = "Cutpurse",
	description = "Combat engineer. Fights, builds outposts deep in enemy land, and jams radar around it.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	moveClass = "AMPHIB_WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "ARMORED", "WORKER", "JAMMER" },
	armorClass = "ARMORED",
	cost = { supply = 1100, power = 13000, buildTime = 28000 },
	health = 1600,
	movement = { maxSpeed = 32.2, accel = 45, brake = 58, turnRate = 400 },
	sensors = { sight = 250, radar = 190, radarError = 30, jam = 60, jamDrain = 10 },
	buildPower = 180,
	buildRange = 88,
	buildOptions = { "chs_extractor", "chs_solar", "chs_guard", "chs_thorn", "chs_eye", "chs_smog", "chs_nano" },
	weapons = {
		{ def = "chs_cutpurse_blaster", turretPiece = "torso", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "nano", "nano1", "muzzle" },
	icon = "worker",
	model = "chs_cutpurse",
})
