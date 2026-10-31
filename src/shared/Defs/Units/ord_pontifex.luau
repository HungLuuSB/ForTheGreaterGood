--!strict
-- Pontifex: Order's T1 amphibious constructor (S-230, the BAR roster program's batch 1;
-- BAR's armbeaver). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "ord_pontifex",
	name = "Pontifex",
	description = "Amphibious worker. Builds the T1 economy on land and under the sea.",
	faction = "order",
	tier = 1,
	domain = "ground",
	moveClass = "AMPHIB",
	footprint = 1, -- (C's blockout)
	cost = { supply = 120, power = 1500, buildTime = 3000 },
	health = 700,
	movement = { maxSpeed = 13, accel = 9, brake = 18, turnRate = 100 },
	sensors = { sight = 100 },
	buildPower = 90,
	buildRange = 45,
	buildOptions = { "ord_extractor", "ord_solar", "ord_advsolar", "ord_capacitor", "ord_windmill", "ord_converter", "ord_depot", "ord_vehplant", "ord_botlab", "ord_advvehplant", "ord_sentry_tower", "ord_beamer", "ord_overwatch", "ord_gauntlet", "ord_vigil", "ord_watchtower", "ord_curtain", "ord_barrier", "ord_nano", "ord_seaextractor", "ord_shipyard", "ord_hoverdock" },
	icon = "worker",
	model = "ord_pontifex",
})
