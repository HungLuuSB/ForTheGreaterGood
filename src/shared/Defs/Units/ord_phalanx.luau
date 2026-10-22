--!strict
local Templates = require("../Templates")

-- Order shield dome generator (S-79, client request 40; the user's rules
-- through the client's C-87 prototype; Sim/Shield). Enemy shells that come
-- into the field round its dome slow, stop and are thrown back out, live;
-- heavy ones break through when the charge is low. Recharging draws power.
-- Counters: sustained fire, heavy shells, hitscan, units inside.
return Templates.extend(Templates.Structure, {
	id = "ord_phalanx",
	name = "Phalanx",
	description = "Shield dome. Turns enemy shells back while charged; recharging draws power.",
	faction = "order",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 400, power = 5000, buildTime = 14000 },
	health = 2800,
	footprint = 2,
	sensors = { sight = 120 },
	shield = { radius = 120, capacity = 300, recharge = 15, power = 40 }, -- 10x (S-80)
	pieces = { "base", "core" },
	icon = "shield",
	model = "ord_phalanx",
})
