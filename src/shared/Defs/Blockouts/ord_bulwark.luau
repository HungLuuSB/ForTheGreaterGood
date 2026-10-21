--!strict
-- Bulwark (Order gun turret, T1, footprint 1): a heavy armored base with
-- sloped sides and a broad wedge-fronted turret with a long gun, team plate
-- on the turret roof, cyan sight. Model space, forward = -Z
-- (docs/contracts/rig.md).

return {
	id = "ord_bulwark",
	parts = {
		{ name = "base", shape = "box", size = { 5.4, 2, 5.4 }, at = { 0, 1, 0 }, color = "hull" },
		{ name = "slopeF", parent = "base", shape = "wedge", size = { 5.4, 2, 1 }, at = { 0, 1, -3.2 }, color = "hull" },
		{ name = "slopeB", parent = "base", shape = "wedge", size = { 5.4, 2, 1 }, at = { 0, 1, 3.2 }, rot = { 0, 180, 0 }, color = "hull" },
		{ name = "slopeL", parent = "base", shape = "wedge", size = { 5.4, 2, 1 }, at = { -3.2, 1, 0 }, rot = { 0, 90, 0 }, color = "hull" },
		{ name = "slopeR", parent = "base", shape = "wedge", size = { 5.4, 2, 1 }, at = { 3.2, 1, 0 }, rot = { 0, -90, 0 }, color = "hull" },
		{ name = "ring", parent = "base", shape = "cylinder", axis = "y", size = { 4, 0.3, 4 }, at = { 0, 2.15, 0 }, color = "dark" },

		{ name = "turret", parent = "base", shape = "box", size = { 3.8, 1.6, 3.4 }, at = { 0, 3.1, 0.4 }, pivot = { 0, 2.3, 0 }, color = "hull" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 3.8, 1.6, 1.2 }, at = { 0, 3.1, -1.9 }, color = "hull" },
		{ name = "roofTeam", parent = "turret", shape = "box", size = { 2.8, 0.1, 2.4 }, at = { 0, 3.95, 0.6 }, color = "team" },
		{ name = "sight", parent = "turret", shape = "box", size = { 0.6, 0.4, 0.1 }, at = { 1.2, 3.5, -1.36 }, color = "glass" },
		{ name = "gun", parent = "turret", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 5 }, at = { 0, 3.1, -4.6 }, color = "metal" },
		{ name = "brake", parent = "turret", shape = "box", size = { 0.8, 0.7, 0.6 }, at = { 0, 3.1, -7.0 }, color = "dark" },
	},
	attachments = {
		{ name = "muzzle", parent = "turret", at = { 0, 3.1, -7.4 } },
	},
}
