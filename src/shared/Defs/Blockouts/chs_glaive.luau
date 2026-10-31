--!strict
-- Glaive (Chaos assault hovertank with a heavy laser): a long skirted hull and
-- a turret with a long laser lance. Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "chs_glaive",
	parts = {
		{ name = "base", shape = "box", size = { 6, 0.8, 9 }, at = { 0, 0.4, 0 }, color = "dark" },
		{ name = "bowSkirt", parent = "base", shape = "wedge", size = { 6, 0.8, 1.8 }, at = { 0, 0.4, -5.4 }, color = "dark" },
		{ name = "hull", parent = "base", shape = "box", size = { 4.92, 1.1, 7.65 }, at = { 0, 1.35, 0.1 }, color = "hull" },
		{ name = "prow", parent = "base", shape = "wedge", size = { 4.92, 1.1, 1.98 }, at = { 0, 1.35, -4.77 }, color = "hull" },
		{ name = "fan1", parent = "base", shape = "cylinder", axis = "y", size = { 1.8, 0.3, 1.8 }, at = { -1.68, 2.05, 2.97 }, color = "metal" },
		{ name = "fanGuard1", parent = "base", shape = "cylinder", axis = "y", size = { 2.04, 0.12, 2.04 }, at = { -1.68, 2.24, 2.97 }, color = "dark" },
		{ name = "fan2", parent = "base", shape = "cylinder", axis = "y", size = { 1.8, 0.3, 1.8 }, at = { 1.68, 2.05, 2.97 }, color = "metal" },
		{ name = "fanGuard2", parent = "base", shape = "cylinder", axis = "y", size = { 2.04, 0.12, 2.04 }, at = { 1.68, 2.24, 2.97 }, color = "dark" },
		{ name = "railL", parent = "base", shape = "box", size = { 0.15, 0.4, 7.2 }, at = { -3, 1, 0 }, color = "metal" },
		{ name = "railR", parent = "base", shape = "box", size = { 0.15, 0.4, 7.2 }, at = { 3, 1, 0 }, color = "metal" },
		{ name = "turret", parent = "base", shape = "box", size = { 3, 1, 3.2 }, at = { 0, 2.4, 0.2 }, color = "hull" },
		{ name = "turretSpike", parent = "turret", shape = "wedge", size = { 1.5, 0.6, 1.28 }, at = { 0, 3, -0.44 }, color = "dark" },
		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.45, 0.45, 5 }, at = { 0, 2.4, -3.9 }, pivot = { 0, 2.4, -1.4 }, color = "metal" },
		{ name = "lens", parent = "barrel", shape = "cylinder", axis = "z", size = { 0.8, 0.8, 0.3 }, at = { 0, 2.4, -6 }, color = "glass" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 2.4, -6.4 } },
	},
}
