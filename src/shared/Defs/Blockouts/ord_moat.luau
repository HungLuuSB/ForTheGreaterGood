--!strict
-- Moat (Order floating turret, T1, footprint 1): an armored floating
-- casemate with a twin gun house (`turret`). Model space, forward = -Z.

return {
	id = "ord_moat",
	parts = {
		{ name = "base", shape = "box", size = { 6.4, 1.6, 6.4 }, at = { 0, 0.4, 0 }, color = "hull" },
		{ name = "wallF", parent = "base", shape = "wedge", size = { 6.4, 1.6, 0.8 }, at = { 0, 0.4, -3.6 }, color = "hull" },
		{ name = "team", parent = "base", shape = "box", size = { 4, 0.08, 1 }, at = { 0, 1.24, 2.4 }, color = "team" },
		{ name = "light", parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { 2.6, 1.45, 2.6 }, color = "glass" },
		{ name = "turret", parent = "base", shape = "box", size = { 3.2, 1.4, 3.2 }, at = { 0, 1.9, 0 }, pivot = { 0, 1.2, 0 }, color = "hull" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 3.2, 1.4, 1.28 }, at = { 0, 1.9, -2.24 }, color = "hull" },
		{ name = "turretBarrel0", parent = "turret", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 3.6 }, at = { -0.225, 1.9, -4.68 }, color = "metal" },
		{ name = "turretBarrel1", parent = "turret", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 3.6 }, at = { 0.225, 1.9, -4.68 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "turret", at = { 0, 1.9, -6.58 } },
	},
}
