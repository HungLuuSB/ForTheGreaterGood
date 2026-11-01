--!strict
-- Draftsman: Order's advanced construction bot (S-233, the BAR roster program's batch 2;
-- BAR's armack). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "ord_draftsman",
	name = "Draftsman",
	description = "Advanced construction bot. Builds the T2 base, and climbs steep slopes.",
	faction = "order",
	tier = 2,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "WORKER" },
	armorClass = "LIGHT",
	cost = { supply = 390, power = 4700, buildTime = 9800 },
	health = 830,
	movement = { maxSpeed = 14, accel = 20, brake = 25, turnRate = 400 },
	sensors = { sight = 170 },
	buildPower = 200,
	buildRange = 45,
	buildOptions = { "ord_extractor", "ord_solar", "ord_windmill", "ord_converter", "ord_depot", "ord_advextractor", "ord_fusion", "ord_advconverter", "ord_advdepot", "ord_advcapacitor", "ord_advfusion", "ord_advvehplant", "ord_advbotlab", "ord_gantry", "ord_bastion", "ord_aegis", "ord_edict", "ord_beacon", "ord_veilspire", "ord_tribunal", "ord_reckoning", "ord_witness", "ord_barrier", "ord_citadel", "ord_phalanx", "ord_radiance", "ord_lumen", "ord_sanction", "ord_providence", "ord_sanctum" },
	pieces = { "base", "torso", "nano", "nano1" },
	icon = "worker",
	model = "ord_draftsman",
})
