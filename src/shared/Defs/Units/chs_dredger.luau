--!strict
-- Dredger: Chaos's T1 amphibious constructor (S-230, the BAR roster program's batch 1;
-- BAR's cormuskrat). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "chs_dredger",
	name = "Dredger",
	description = "Amphibious worker. Builds the T1 economy on land and under the sea.",
	faction = "chaos",
	tier = 1,
	domain = "ground",
	moveClass = "AMPHIB",
	footprint = 1, -- (C's blockout)
	cost = { supply = 120, power = 1600, buildTime = 3000 },
	health = 750,
	movement = { maxSpeed = 13, accel = 9, brake = 18, turnRate = 100 },
	sensors = { sight = 100 },
	buildPower = 85,
	buildRange = 45,
	buildOptions = { "chs_extractor", "chs_solar", "chs_advsolar", "chs_accumulator", "chs_windmill", "chs_converter", "chs_depot", "chs_vehplant", "chs_botlab", "chs_advvehplant", "chs_guard", "chs_twin_guard", "chs_geryon", "chs_talos", "chs_thorn", "chs_eye", "chs_smog", "chs_nano", "chs_seaextractor", "chs_shipyard", "chs_skimyard" },
	icon = "worker",
	model = "chs_dredger",
})
