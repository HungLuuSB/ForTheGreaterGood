--!strict
-- Volley (Order hover rocket artillery): a skirted hull with a tall rocket box
-- that pitches up to fire. Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "ord_volley",
	parts = {
		{ name = "base", shape = "box", size = { 5, 0.8, 7.6 }, at = { 0, 0.4, 0 }, color = "dark" },
		{ name = "bowSkirt", parent = "base", shape = "wedge", size = { 5, 0.8, 1.52 }, at = { 0, 0.4, -4.56 }, color = "dark" },
		{ name = "hull", parent = "base", shape = "box", size = { 4.1, 0.9, 6.46 }, at = { 0, 1.25, 0.1 }, color = "hull" },
		{ name = "prow", parent = "base", shape = "wedge", size = { 4.1, 0.9, 1.672 }, at = { 0, 1.25, -4.028 }, color = "hull" },
		{ name = "fan1", parent = "base", shape = "cylinder", axis = "y", size = { 1.5, 0.3, 1.5 }, at = { -1.4, 1.85, 2.508 }, color = "metal" },
		{ name = "fanGuard1", parent = "base", shape = "cylinder", axis = "y", size = { 1.7, 0.12, 1.7 }, at = { -1.4, 2.04, 2.508 }, color = "dark" },
		{ name = "fan2", parent = "base", shape = "cylinder", axis = "y", size = { 1.5, 0.3, 1.5 }, at = { 1.4, 1.85, 2.508 }, color = "metal" },
		{ name = "fanGuard2", parent = "base", shape = "cylinder", axis = "y", size = { 1.7, 0.12, 1.7 }, at = { 1.4, 2.04, 2.508 }, color = "dark" },
		{ name = "stripe", parent = "base", shape = "box", size = { 2.05, 0.06, 2.28 }, at = { 0, 1.73, -0.912 }, color = "team" },
		{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 2.1, 0.5, 2.1 }, at = { 0, 1.95, 0 }, color = "dark" },
		{ name = "launcher", parent = "turret", shape = "box", size = { 3, 1.6, 2.8 }, at = { 0, 3, 0 }, color = "team" },
		{ name = "tube1", parent = "turret", shape = "cylinder", axis = "z", size = { 0.45, 0.45, 0.1 }, at = { -0.9, 3, -1.45 }, color = "glass" },
		{ name = "tube2", parent = "turret", shape = "cylinder", axis = "z", size = { 0.45, 0.45, 0.1 }, at = { -0.3, 3, -1.45 }, color = "glass" },
		{ name = "tube3", parent = "turret", shape = "cylinder", axis = "z", size = { 0.45, 0.45, 0.1 }, at = { 0.3, 3, -1.45 }, color = "glass" },
		{ name = "tube4", parent = "turret", shape = "cylinder", axis = "z", size = { 0.45, 0.45, 0.1 }, at = { 0.9, 3, -1.45 }, color = "glass" },
	},
	attachments = {
		{ name = "muzzle", parent = "turret", at = { 0, 3, -1.6 } },
	},
}
