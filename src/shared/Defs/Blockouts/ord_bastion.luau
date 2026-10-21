--!strict
-- Bastion (Order heavy turret, T2, footprint 1): a taller armored base with
-- sloped sides and a broad wedge turret with twin long guns, team plate on
-- the roof, cyan sight. Model space, forward = -Z.

return {
	id = "ord_bastion",
	parts = {
		{ name = "base", shape = "box", size = { 5.6, 2.6, 5.6 }, at = { 0, 1.3, 0 }, color = "hull" },
		{ name = "slopeF", parent = "base", shape = "wedge", size = { 5.6, 2.6, 0.9 }, at = { 0, 1.3, -3.25 }, color = "hull" },
		{ name = "slopeB", parent = "base", shape = "wedge", size = { 5.6, 2.6, 0.9 }, at = { 0, 1.3, 3.25 }, rot = { 0, 180, 0 }, color = "hull" },
		{ name = "slopeL", parent = "base", shape = "wedge", size = { 5.6, 2.6, 0.9 }, at = { -3.25, 1.3, 0 }, rot = { 0, 90, 0 }, color = "hull" },
		{ name = "slopeR", parent = "base", shape = "wedge", size = { 5.6, 2.6, 0.9 }, at = { 3.25, 1.3, 0 }, rot = { 0, -90, 0 }, color = "hull" },

		{ name = "turret", parent = "base", shape = "box", size = { 4.4, 2, 4 }, at = { 0, 3.6, 0.4 }, pivot = { 0, 2.6, 0 }, color = "hull" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 4.4, 2, 1.4 }, at = { 0, 3.6, -2.3 }, color = "hull" },
		{ name = "roofTeam", parent = "turret", shape = "box", size = { 3.4, 0.1, 3 }, at = { 0, 4.65, 0.6 }, color = "team" },
		{ name = "sight", parent = "turret", shape = "box", size = { 0.6, 0.4, 0.1 }, at = { 1.5, 4.1, -1.64 }, color = "glass" },
		{ name = "gunL", parent = "turret", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 5.6 }, at = { -0.7, 3.6, -5.4 }, color = "metal" },
		{ name = "gunR", parent = "turret", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 5.6 }, at = { 0.7, 3.6, -5.4 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "turret", at = { -0.7, 3.6, -8.25 } },
	},
}
