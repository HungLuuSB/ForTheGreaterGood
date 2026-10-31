--!strict
-- Experimental Gantry: the T3 factory (S-209, the user's playtest 3 H39; BAR's armshltx).
local Templates = require("../Templates")

return Templates.extend(Templates.Structure, {
	id = "ord_gantry",
	name = "Experimental Gantry",
	description = "T3 factory. Builds experimental assault mechs.",
	faction = "order",
	tier = 3,
	cost = { supply = 3500, power = 30000, buildTime = 60000 },
	health = 12000,
	footprint = 7, -- size shows tech level (S-104)
	buildPower = 400,
	buildOptions = { "ord_titan", "ord_thunderer" },
	icon = "factory",
	model = "ord_gantry",
})
