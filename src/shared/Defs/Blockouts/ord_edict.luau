--!strict
-- Edict (Order artillery emplacement, T2, footprint 3): a sloped armored
-- emplacement with a big casemate turret and a very long gun, team plate on
-- the turret roof, cyan sight. Model space, forward = -Z.

return {
	id = "ord_edict",
	parts = {
		{ name = "base", shape = "box", size = { 18, 2, 18 }, at = { 0, 1, 1 }, color = "hull" },
		{ name = "wallF", parent = "base", shape = "wedge", size = { 18, 2, 3 }, at = { 0, 1, -9.5 }, color = "hull" },
		{ name = "ring", parent = "base", shape = "cylinder", axis = "y", size = { 10, 0.6, 10 }, at = { 0, 2.3, 1 }, color = "dark" },
		{ name = "ammo", parent = "base", shape = "box", size = { 4, 2, 3 }, at = { 6, 3, 7 }, color = "hull" },

		{ name = "turret", parent = "base", shape = "box", size = { 8, 3.4, 8 }, at = { 0, 4.3, 1.6 }, pivot = { 0, 2.6, 1 }, color = "hull" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 8, 3.4, 2.4 }, at = { 0, 4.3, -3.6 }, color = "hull" },
		{ name = "roofTeam", parent = "turret", shape = "box", size = { 6, 0.1, 6 }, at = { 0, 6.05, 2 }, color = "team" },
		{ name = "sight", parent = "turret", shape = "box", size = { 0.9, 0.5, 0.1 }, at = { 2.6, 5.4, -2.45 }, color = "glass" },
		{ name = "gun", parent = "turret", shape = "cylinder", axis = "z", size = { 1.1, 1.1, 14 }, at = { 0, 4.5, -11.4 }, color = "metal" },
		{ name = "brake", parent = "turret", shape = "box", size = { 1.6, 1.3, 1.2 }, at = { 0, 4.5, -18.6 }, color = "dark" },
	},
	attachments = {
		{ name = "muzzle", parent = "turret", at = { 0, 4.5, -19.3 } },
	},
}
