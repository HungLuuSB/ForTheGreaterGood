--!strict
-- Drifter: Chaos's T1 hover constructor (S-230, the BAR roster program's batch 1;
-- BAR's corch). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "chs_drifter",
	name = "Drifter",
	description = "Hover worker. Builds the T1 economy on land and water alike.",
	faction = "chaos",
	tier = 1,
	domain = "ground",
	moveClass = "HOVER",
	footprint = 1, -- (C's blockout)
	cost = { supply = 130, power = 1500, buildTime = 3300 },
	health = 840,
	movement = { maxSpeed = 16, accel = 11, brake = 22, turnRate = 100 },
	sensors = { sight = 120 },
	buildPower = 100,
	buildRange = 45,
	buildOptions = { "chs_extractor", "chs_solar", "chs_advsolar", "chs_accumulator", "chs_windmill", "chs_converter", "chs_depot", "chs_vehplant", "chs_botlab", "chs_advvehplant", "chs_guard", "chs_twin_guard", "chs_geryon", "chs_talos", "chs_thorn", "chs_eye", "chs_smog", "chs_nano", "chs_seaextractor", "chs_shipyard", "chs_skimyard" },
	icon = "worker",
	model = "chs_drifter",
})
