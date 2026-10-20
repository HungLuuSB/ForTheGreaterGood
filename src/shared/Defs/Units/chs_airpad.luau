--!strict
local Templates = require("../Templates")

-- Placeholder rearm pad (guide 8.6, 12.2): aircraft land here to rearm,
-- paying supply and power per round through the team account.
return Templates.extend(Templates.Structure, {
	id = "chs_airpad",
	name = "Roost",
	description = "Rearm pad. Refuels and rearms one aircraft at a time.",
	faction = "chaos",
	cost = { supply = 120, power = 900, buildTime = 2400 },
	health = 1300,
	footprint = 3,
	rearmPads = 1,
	model = "chs_airpad",
	icon = "airpad",
})
