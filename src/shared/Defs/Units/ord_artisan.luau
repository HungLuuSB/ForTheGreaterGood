--!strict
-- Artisan: Order's bot constructor (S-181, the playtest's new units).
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "ord_artisan",
	name = "Artisan",
	description = "Bot constructor. Builds and reclaims, and climbs steep slopes.",
	faction = "order",
	domain = "ground",
	moveClass = "WALKER", -- bots climb steep slopes and turn on the spot
	footprint = 1,
	categories = { "GROUND", "WORKER" },
	cost = { supply = 110, power = 1300, buildTime = 2900 },
	health = 480,
	movement = { maxSpeed = 20.4, accel = 30, brake = 40, turnRate = 400 },
	sensors = { sight = 100 },
	buildPower = 80,
	buildRange = 40,
	canResurrect = true,
	buildOptions = { "ord_extractor", "ord_solar", "ord_advsolar", "ord_capacitor", "ord_windmill", "ord_converter", "ord_depot", "ord_botlab", "ord_advbotlab", "ord_sentry_tower", "ord_beamer", "ord_overwatch", "ord_gauntlet", "ord_vigil", "ord_watchtower", "ord_curtain", "ord_barrier", "ord_nano" },
	icon = "worker",
	model = "ord_artisan",
})
