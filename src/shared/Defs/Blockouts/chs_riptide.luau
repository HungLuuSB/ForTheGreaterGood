--!strict
-- Riptide (Chaos floating turret, T1, footprint 1): a round float with an
-- open single-gun mount (`turret`). Model space, forward = -Z.

return {
	id = "chs_riptide",
	parts = {
		{ name = "base", shape = "cylinder", axis = "y", size = { 6.4, 1, 6.4 }, at = { 0, 0.2, 0 }, color = "dark" },
		{ name = "float", parent = "base", shape = "cylinder", axis = "y", size = { 6.8, 0.6, 6.8 }, at = { 0, -0.2, 0 }, color = "metal" },
		{ name = "team", parent = "base", shape = "box", size = { 2.4, 0.08, 1 }, at = { 0, 0.74, 2.2 }, color = "team" },
		{ name = "light", parent = "base", shape = "box", size = { 0.4, 0.4, 0.4 }, at = { 2.4, 0.9, 1.6 }, color = "glass" },
		{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 3, 1.2, 3 }, at = { 0, 1.3, 0 }, pivot = { 0, 0.7, 0 }, color = "hull" },
		{ name = "turretBarrel0", parent = "turret", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 3.4 }, at = { 0, 1.3, -3.2 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "turret", at = { 0, 1.3, -5 } },
	},
}
