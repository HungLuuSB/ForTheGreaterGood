--!strict
-- Scrounger: Chaos's combat engineer (S-233, the BAR roster program's batch 2;
-- BAR's corfast). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "chs_scrounger",
	name = "Scrounger",
	description = "Combat engineer. A quick T2 worker that builds the T1 base at the front.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "WORKER" },
	armorClass = "LIGHT",
	cost = { supply = 180, power = 2200, buildTime = 5000 },
	health = 740,
	movement = { maxSpeed = 39.2, accel = 55, brake = 71, turnRate = 420 },
	sensors = { sight = 220 },
	buildPower = 110,
	buildRange = 45,
	buildOptions = { "chs_extractor", "chs_solar", "chs_advsolar", "chs_accumulator", "chs_windmill", "chs_converter", "chs_depot", "chs_vehplant", "chs_botlab", "chs_advbotlab", "chs_guard", "chs_twin_guard", "chs_geryon", "chs_talos", "chs_thorn", "chs_eye", "chs_smog", "chs_nano", "chs_skimyard" },
	pieces = { "base", "torso", "nano", "nano1" },
	icon = "worker",
	model = "chs_scrounger",
})
