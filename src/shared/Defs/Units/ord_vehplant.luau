--!strict
local Templates = require("../Templates")

return Templates.extend(Templates.Structure, {
	id = "ord_vehplant",
	name = "Vehicle Plant",
	description = "T1 factory: ground worker and T1 ground units.",
	faction = "order",
	cost = { supply = 600, power = 1200, buildTime = 7000 },
	health = 3000,
	footprint = 4, -- size shows tech level (S-104)
	buildPower = 200, -- doubled: T1 units in about half the time (S-94, client request 42b)
	buildOptions = { "ord_mason", "ord_herald", "ord_lancer", "ord_verdict", "ord_halo", "ord_oracle" },
	model = "ord_vehplant",
	icon = "factory",
})
