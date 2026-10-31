--!strict
-- Tempest (Order heavy hovertank, T3): a large skirted hull, four fans and a
-- heavy turret with twin long guns. Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "ord_tempest",
	parts = {
		{ name = "base", shape = "box", size = { 8.4, 0.8, 12 }, at = { 0, 0.4, 0 }, color = "dark" },
		{ name = "bowSkirt", parent = "base", shape = "wedge", size = { 8.4, 0.8, 2.4 }, at = { 0, 0.4, -7.2 }, color = "dark" },
		{ name = "hull", parent = "base", shape = "box", size = { 6.888, 1.5, 10.2 }, at = { 0, 1.55, 0.1 }, color = "hull" },
		{ name = "prow", parent = "base", shape = "wedge", size = { 6.888, 1.5, 2.64 }, at = { 0, 1.55, -6.36 }, color = "hull" },
		{ name = "fan1", parent = "base", shape = "cylinder", axis = "y", size = { 2.52, 0.3, 2.52 }, at = { -2.352, 2.45, 3.96 }, color = "metal" },
		{ name = "fanGuard1", parent = "base", shape = "cylinder", axis = "y", size = { 2.856, 0.12, 2.856 }, at = { -2.352, 2.64, 3.96 }, color = "dark" },
		{ name = "fan2", parent = "base", shape = "cylinder", axis = "y", size = { 2.52, 0.3, 2.52 }, at = { -0.784, 2.45, 3.96 }, color = "metal" },
		{ name = "fanGuard2", parent = "base", shape = "cylinder", axis = "y", size = { 2.856, 0.12, 2.856 }, at = { -0.784, 2.64, 3.96 }, color = "dark" },
		{ name = "fan3", parent = "base", shape = "cylinder", axis = "y", size = { 2.52, 0.3, 2.52 }, at = { 0.784, 2.45, 3.96 }, color = "metal" },
		{ name = "fanGuard3", parent = "base", shape = "cylinder", axis = "y", size = { 2.856, 0.12, 2.856 }, at = { 0.784, 2.64, 3.96 }, color = "dark" },
		{ name = "fan4", parent = "base", shape = "cylinder", axis = "y", size = { 2.52, 0.3, 2.52 }, at = { 2.352, 2.45, 3.96 }, color = "metal" },
		{ name = "fanGuard4", parent = "base", shape = "cylinder", axis = "y", size = { 2.856, 0.12, 2.856 }, at = { 2.352, 2.64, 3.96 }, color = "dark" },
		{ name = "stripe", parent = "base", shape = "box", size = { 3.444, 0.06, 3.6 }, at = { 0, 2.33, -1.44 }, color = "team" },
		{ name = "turret", parent = "base", shape = "box", size = { 4.8, 1.4, 4.6 }, at = { 0, 3, -0.6 }, color = "team" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 4.8, 1.4, 1.38 }, at = { 0, 3, -3.59 }, color = "team" },
		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 6 }, at = { 0, 3, -5.9 }, pivot = { 0, 3, -2.9 }, color = "metal" },
		{ name = "barrel2", parent = "barrel", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 6 }, at = { 1.1, 3, -5.9 }, color = "metal" },
		{ name = "barrel1", parent = "barrel", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 6 }, at = { -1.1, 3, -5.9 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 3, -8.9 } },
		{ name = "muzzle2", parent = "barrel", at = { 1.1, 3, -8.9 } },
	},
}
