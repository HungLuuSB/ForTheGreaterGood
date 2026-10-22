--!strict
-- Lumen (Order flak tower, T2, footprint 1; S-96): a sloped armored base
-- and pedestal under a boxy `turret` with a twin flak gun either side, laid
-- up at 35 degrees (the def turns only `turret`; flak bursts at altitude),
-- and a cyan fire-control sensor between them. Muzzles at the outer barrels'
-- tips. Model space, forward = -Z.

-- footprint 1 -> 2 (size scale, M-26 / S-104): scaled until the redesign lands
return require("./Scale").scaled({
	id = "ord_lumen",
	parts = {
		{ name = "base", shape = "box", size = { 6, 1.6, 6 }, at = { 0, 0.8, 0 }, color = "hull" },
		{ name = "slopeF", parent = "base", shape = "wedge", size = { 6, 1.6, 1 }, at = { 0, 0.8, -3.5 }, color = "hull" },
		{ name = "slopeB", parent = "base", shape = "wedge", size = { 6, 1.6, 1 }, at = { 0, 0.8, 3.5 }, rot = { 0, 180, 0 }, color = "hull" },
		{ name = "teamB", parent = "base", shape = "box", size = { 3, 0.08, 1 }, at = { 0, 1.64, 2.3 }, color = "team" },
		{ name = "pedestal", parent = "base", shape = "cylinder", axis = "y", size = { 2.2, 1.6, 2.2 }, at = { 0, 2.4, 0 }, color = "dark" },

		{ name = "turret", parent = "base", shape = "box", size = { 2.8, 1.6, 2.8 }, at = { 0, 4, 0.2 }, pivot = { 0, 3.2, 0 }, color = "hull" },
		{ name = "headTeam", parent = "turret", shape = "box", size = { 2.0, 0.08, 1.8 }, at = { 0, 4.84, 0.5 }, color = "team" },
		{ name = "sensor", parent = "turret", shape = "box", size = { 1.0, 0.5, 0.1 }, at = { 0, 4.2, -1.25 }, color = "glass" },
		{ name = "mountL", parent = "turret", shape = "box", size = { 0.8, 1.2, 1.6 }, at = { -1.8, 4.2, -0.2 }, color = "dark" },
		{ name = "mountR", parent = "turret", shape = "box", size = { 0.8, 1.2, 1.6 }, at = { 1.8, 4.2, -0.2 }, color = "dark" },
		-- twin barrels each side, from (x, 4.3, -1.0) up 35 degrees, 3 long
		{ name = "gunL1", parent = "turret", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 3 }, at = { -2.0, 5.16, -2.23 }, rot = { 35, 0, 0 }, color = "metal" },
		{ name = "gunL2", parent = "turret", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 3 }, at = { -1.6, 5.16, -2.23 }, rot = { 35, 0, 0 }, color = "metal" },
		{ name = "gunR1", parent = "turret", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 3 }, at = { 1.6, 5.16, -2.23 }, rot = { 35, 0, 0 }, color = "metal" },
		{ name = "gunR2", parent = "turret", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 3 }, at = { 2.0, 5.16, -2.23 }, rot = { 35, 0, 0 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "turret", at = { -1.8, 6.02, -3.46 } },
		{ name = "muzzle2", parent = "turret", at = { 1.8, 6.02, -3.46 } },
	},
}, 2.0)
