--!strict
-- Magistrate: Order's T2 combat engineer (S-230, the BAR roster program's batch 1;
-- BAR's armconsul). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "ord_magistrate",
	name = "Magistrate",
	description = "Combat engineer. A tough, quick T2 worker that builds the T1 base at the front.",
	faction = "order",
	tier = 2,
	domain = "ground",
	moveClass = "TRACKED",
	footprint = 2, -- (C's blockout)
	cost = { supply = 170, power = 2000, buildTime = 4300 },
	health = 850,
	movement = { maxSpeed = 20, accel = 14, brake = 28, turnRate = 80 },
	sensors = { sight = 160 },
	buildPower = 160,
	buildRange = 45,
	buildOptions = { "ord_extractor", "ord_solar", "ord_advsolar", "ord_capacitor", "ord_windmill", "ord_converter", "ord_depot", "ord_vehplant", "ord_botlab", "ord_advvehplant", "ord_sentry_tower", "ord_beamer", "ord_overwatch", "ord_gauntlet", "ord_vigil", "ord_watchtower", "ord_curtain", "ord_barrier", "ord_nano", "ord_hoverdock" },
	icon = "worker",
	model = "ord_magistrate",
})
