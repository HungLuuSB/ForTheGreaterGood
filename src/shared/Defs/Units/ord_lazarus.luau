--!strict
-- Lazarus: a helper bot (S-181, the playtest's new units).
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "ord_lazarus",
	name = "Lazarus",
	description = "Field medic bot. Repairs, resurrects and reclaims wrecks; builds nothing.",
	faction = "order",
	domain = "ground",
	moveClass = "WALKER", -- bots climb steep slopes and turn on the spot
	footprint = 1,
	categories = { "GROUND", "WORKER" },
	cost = { supply = 100, power = 1200, buildTime = 2600 },
	health = 450,
	movement = { maxSpeed = 22.8, accel = 32, brake = 42, turnRate = 400 },
	sensors = { sight = 110 },
	buildPower = 90,
	buildRange = 40,
	canResurrect = true,
	icon = "worker",
	model = "ord_lazarus",
})
