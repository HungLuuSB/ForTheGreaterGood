--!strict
-- Typhon (Chaos heavy laser hovertank, T3): a big skirted hull, four fans, a
-- massive turret with a heavy laser and exposed capacitor coils. Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "chs_typhon",
	parts = {
		{ name = "base", shape = "box", size = { 8.4, 0.8, 12 }, at = { 0, 0.4, 0 }, color = "dark" },
		{ name = "bowSkirt", parent = "base", shape = "wedge", size = { 8.4, 0.8, 2.4 }, at = { 0, 0.4, -7.2 }, color = "dark" },
		{ name = "hull", parent = "base", shape = "box", size = { 6.888, 1.4, 10.2 }, at = { 0, 1.5, 0.1 }, color = "hull" },
		{ name = "prow", parent = "base", shape = "wedge", size = { 6.888, 1.4, 2.64 }, at = { 0, 1.5, -6.36 }, color = "hull" },
		{ name = "fan1", parent = "base", shape = "cylinder", axis = "y", size = { 2.52, 0.3, 2.52 }, at = { -2.352, 2.35, 3.96 }, color = "metal" },
		{ name = "fanGuard1", parent = "base", shape = "cylinder", axis = "y", size = { 2.856, 0.12, 2.856 }, at = { -2.352, 2.54, 3.96 }, color = "dark" },
		{ name = "fan2", parent = "base", shape = "cylinder", axis = "y", size = { 2.52, 0.3, 2.52 }, at = { -0.784, 2.35, 3.96 }, color = "metal" },
		{ name = "fanGuard2", parent = "base", shape = "cylinder", axis = "y", size = { 2.856, 0.12, 2.856 }, at = { -0.784, 2.54, 3.96 }, color = "dark" },
		{ name = "fan3", parent = "base", shape = "cylinder", axis = "y", size = { 2.52, 0.3, 2.52 }, at = { 0.784, 2.35, 3.96 }, color = "metal" },
		{ name = "fanGuard3", parent = "base", shape = "cylinder", axis = "y", size = { 2.856, 0.12, 2.856 }, at = { 0.784, 2.54, 3.96 }, color = "dark" },
		{ name = "fan4", parent = "base", shape = "cylinder", axis = "y", size = { 2.52, 0.3, 2.52 }, at = { 2.352, 2.35, 3.96 }, color = "metal" },
		{ name = "fanGuard4", parent = "base", shape = "cylinder", axis = "y", size = { 2.856, 0.12, 2.856 }, at = { 2.352, 2.54, 3.96 }, color = "dark" },
		{ name = "railL", parent = "base", shape = "box", size = { 0.15, 0.4, 9.6 }, at = { -4.2, 1, 0 }, color = "metal" },
		{ name = "railR", parent = "base", shape = "box", size = { 0.15, 0.4, 9.6 }, at = { 4.2, 1, 0 }, color = "metal" },
		{ name = "turret", parent = "base", shape = "box", size = { 4.6, 1.6, 4.6 }, at = { 0, 3, -0.4 }, color = "hull" },
		{ name = "turretSpike", parent = "turret", shape = "wedge", size = { 2.3, 0.96, 1.84 }, at = { 0, 3.96, -1.32 }, color = "dark" },
		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 6.4 }, at = { 0, 3, -5.9 }, pivot = { 0, 3, -2.7 }, color = "metal" },
		{ name = "lens", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.4, 1.4, 0.4 }, at = { 0, 3, -8.8 }, color = "glass" },
		{ name = "capL", parent = "turret", shape = "cylinder", axis = "y", size = { 0.8, 2.4, 0.8 }, at = { -1.8, 4.6, 1 }, color = "glass" },
		{ name = "capR", parent = "turret", shape = "cylinder", axis = "y", size = { 0.8, 2.4, 0.8 }, at = { 1.8, 4.6, 1 }, color = "glass" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 3, -9.1 } },
	},
}
