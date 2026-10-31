--!strict
-- Skimwright: Order's T1 hover constructor (S-230, the BAR roster program's batch 1;
-- BAR's armch). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "ord_skimwright",
	name = "Skimwright",
	description = "Hover worker. Builds the T1 economy on land and water alike.",
	faction = "order",
	tier = 1,
	domain = "ground",
	moveClass = "HOVER",
	footprint = 1, -- (C's blockout)
	cost = { supply = 140, power = 1500, buildTime = 3500 },
	health = 780,
	movement = { maxSpeed = 18, accel = 13, brake = 25, turnRate = 100 },
	sensors = { sight = 120 },
	buildPower = 100,
	buildRange = 45,
	buildOptions = { "ord_extractor", "ord_solar", "ord_advsolar", "ord_capacitor", "ord_windmill", "ord_converter", "ord_depot", "ord_vehplant", "ord_botlab", "ord_advvehplant", "ord_sentry_tower", "ord_beamer", "ord_overwatch", "ord_gauntlet", "ord_vigil", "ord_watchtower", "ord_curtain", "ord_barrier", "ord_nano", "ord_seaextractor", "ord_shipyard", "ord_hoverdock" },
	icon = "worker",
	model = "ord_skimwright",
})
