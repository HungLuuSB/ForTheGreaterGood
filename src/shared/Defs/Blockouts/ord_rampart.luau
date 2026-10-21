--!strict
-- Rampart (Order coastal battery, T2, footprint 3): a heavy sea-wall bunker
-- with a sloped front, a broad turret with twin long guns, team plate on
-- the turret roof, cyan lights. Model space, forward = -Z.

return {
	id = "ord_rampart",
	parts = {
		{ name = "base", shape = "box", size = { 20, 3, 16 }, at = { 0, 1.5, 2 }, color = "hull" },
		{ name = "wallF", parent = "base", shape = "wedge", size = { 20, 3, 3.5 }, at = { 0, 1.5, -7.75 }, color = "hull" },
		{ name = "ring", parent = "base", shape = "cylinder", axis = "y", size = { 9, 0.5, 9 }, at = { 0, 3.25, 1 }, color = "dark" },
		{ name = "lightL", parent = "base", shape = "box", size = { 0.7, 0.7, 0.7 }, at = { -9, 3.4, -5 }, color = "glass" },
		{ name = "lightR", parent = "base", shape = "box", size = { 0.7, 0.7, 0.7 }, at = { 9, 3.4, -5 }, color = "glass" },

		{ name = "turret", parent = "base", shape = "box", size = { 9, 2.6, 7 }, at = { 0, 4.8, 1.4 }, pivot = { 0, 3.5, 1 }, color = "hull" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 9, 2.6, 2 }, at = { 0, 4.8, -3.1 }, color = "hull" },
		{ name = "roofTeam", parent = "turret", shape = "box", size = { 7, 0.1, 5 }, at = { 0, 6.15, 1.6 }, color = "team" },
		{ name = "gunL", parent = "turret", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 10 }, at = { -1.6, 4.8, -9 }, color = "metal" },
		{ name = "gunR", parent = "turret", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 10 }, at = { 1.6, 4.8, -9 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "turret", at = { -1.6, 4.8, -14.1 } },
	},
}
