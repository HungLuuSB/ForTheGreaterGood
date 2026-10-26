--!strict
-- Graverobber: a helper bot (S-181, the playtest's new units).
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "chs_graverobber",
	name = "Graverobber",
	description = "Scavenger bot. Repairs, resurrects and reclaims wrecks; builds nothing.",
	faction = "chaos",
	domain = "ground",
	moveClass = "WALKER", -- bots climb steep slopes and turn on the spot
	footprint = 1,
	categories = { "GROUND", "WORKER" },
	cost = { supply = 85, power = 1000, buildTime = 2200 },
	health = 400,
	movement = { maxSpeed = 22.8, accel = 32, brake = 42, turnRate = 400 },
	sensors = { sight = 110 },
	buildPower = 90,
	buildRange = 40,
	canResurrect = true,
	icon = "worker",
	model = "chs_graverobber",
})
