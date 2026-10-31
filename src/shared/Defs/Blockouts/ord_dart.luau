--!strict
-- Dart (Order fast light hover raider): small and narrow, one fan, a light gun. Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "ord_dart",
	parts = {
		{ name = "base", shape = "box", size = { 3.6, 0.8, 5.4 }, at = { 0, 0.4, 0 }, color = "dark" },
		{ name = "bowSkirt", parent = "base", shape = "wedge", size = { 3.6, 0.8, 1.08 }, at = { 0, 0.4, -3.24 }, color = "dark" },
		{ name = "hull", parent = "base", shape = "box", size = { 2.952, 0.7, 4.59 }, at = { 0, 1.15, 0.1 }, color = "hull" },
		{ name = "prow", parent = "base", shape = "wedge", size = { 2.952, 0.7, 1.188 }, at = { 0, 1.15, -2.862 }, color = "hull" },
		{ name = "fan1", parent = "base", shape = "cylinder", axis = "y", size = { 1.08, 0.3, 1.08 }, at = { 0, 1.65, 1.782 }, color = "metal" },
		{ name = "fanGuard1", parent = "base", shape = "cylinder", axis = "y", size = { 1.224, 0.12, 1.224 }, at = { 0, 1.84, 1.782 }, color = "dark" },
		{ name = "stripe", parent = "base", shape = "box", size = { 1.476, 0.06, 1.62 }, at = { 0, 1.53, -0.648 }, color = "team" },
		{ name = "turret", parent = "base", shape = "box", size = { 1.6, 0.6, 1.6 }, at = { 0, 1.8, -0.6 }, color = "team" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 1.6, 0.6, 0.48 }, at = { 0, 1.8, -1.64 }, color = "team" },
		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.22, 0.22, 2.2 }, at = { 0, 1.8, -2.5 }, pivot = { 0, 1.8, -1.4 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 1.8, -3.6 } },
	},
}
