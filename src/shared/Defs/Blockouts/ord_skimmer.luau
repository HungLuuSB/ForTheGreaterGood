--!strict
-- Skimmer (Order hover tank): a skirted hull with a compact gun turret. Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "ord_skimmer",
	parts = {
		{ name = "base", shape = "box", size = { 4.8, 0.8, 7 }, at = { 0, 0.4, 0 }, color = "dark" },
		{ name = "bowSkirt", parent = "base", shape = "wedge", size = { 4.8, 0.8, 1.4 }, at = { 0, 0.4, -4.2 }, color = "dark" },
		{ name = "hull", parent = "base", shape = "box", size = { 3.936, 0.9, 5.95 }, at = { 0, 1.25, 0.1 }, color = "hull" },
		{ name = "prow", parent = "base", shape = "wedge", size = { 3.936, 0.9, 1.54 }, at = { 0, 1.25, -3.71 }, color = "hull" },
		{ name = "fan1", parent = "base", shape = "cylinder", axis = "y", size = { 1.44, 0.3, 1.44 }, at = { -1.344, 1.85, 2.31 }, color = "metal" },
		{ name = "fanGuard1", parent = "base", shape = "cylinder", axis = "y", size = { 1.632, 0.12, 1.632 }, at = { -1.344, 2.04, 2.31 }, color = "dark" },
		{ name = "fan2", parent = "base", shape = "cylinder", axis = "y", size = { 1.44, 0.3, 1.44 }, at = { 1.344, 1.85, 2.31 }, color = "metal" },
		{ name = "fanGuard2", parent = "base", shape = "cylinder", axis = "y", size = { 1.632, 0.12, 1.632 }, at = { 1.344, 2.04, 2.31 }, color = "dark" },
		{ name = "stripe", parent = "base", shape = "box", size = { 1.968, 0.06, 2.1 }, at = { 0, 1.73, -0.84 }, color = "team" },
		{ name = "turret", parent = "base", shape = "box", size = { 2.6, 0.8, 2.6 }, at = { 0, 2.1, -0.2 }, color = "team" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 2.6, 0.8, 0.78 }, at = { 0, 2.1, -1.89 }, color = "team" },
		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.32, 0.32, 3.2 }, at = { 0, 2.1, -3.1 }, pivot = { 0, 2.1, -1.5 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 2.1, -4.7 } },
	},
}
