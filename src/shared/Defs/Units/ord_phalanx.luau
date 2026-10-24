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
	footprint = 3, -- size shows tech level (S-104)
	sensors = { sight = 120 },
	shield = { radius = 120, capacity = 120, recharge = 2, power = 40 }, -- S-150: 600 / 30 (S-86) held full under any focused fire
	pieces = { "base", "core" },
	icon = "shield",
	model = "ord_phalanx",
})
