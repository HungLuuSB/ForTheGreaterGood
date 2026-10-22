--!strict
local Templates = require("../Templates")

-- Chaos shield dome generator (S-79, client request 40): Order's Phalanx
-- smaller and cheaper (Sim/Shield). Enemy shells that come into the field
-- round its dome slow, stop and are thrown back out, live; heavy ones break
-- through when the charge is low. Recharging draws power.
return Templates.extend(Templates.Structure, {
	id = "chs_carapace",
	name = "Carapace",
	description = "Small shield dome. Turns enemy shells back while charged; recharging draws power.",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 280, power = 3500, buildTime = 10000 },
	health = 2000,
	footprint = 2,
	sensors = { sight = 100 },
	shield = { radius = 80, capacity = 1000, recharge = 60, power = 25 }, -- 50x S-79's (S-81)
	pieces = { "base", "core" },
	icon = "shield",
	model = "chs_carapace",
})
