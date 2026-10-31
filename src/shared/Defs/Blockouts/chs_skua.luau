--!strict
-- Skua (Chaos hover anti-air): a skirted hull with a turret of open missile
-- rails that pitch up. Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "chs_skua",
	parts = {
		{ name = "base", shape = "box", size = { 4.8, 0.8, 7 }, at = { 0, 0.4, 0 }, color = "dark" },
		{ name = "bowSkirt", parent = "base", shape = "wedge", size = { 4.8, 0.8, 1.4 }, at = { 0, 0.4, -4.2 }, color = "dark" },
		{ name = "hull", parent = "base", shape = "box", size = { 3.936, 0.8, 5.95 }, at = { 0, 1.2, 0.1 }, color = "hull" },
		{ name = "prow", parent = "base", shape = "wedge", size = { 3.936, 0.8, 1.54 }, at = { 0, 1.2, -3.71 }, color = "hull" },
		{ name = "fan1", parent = "base", shape = "cylinder", axis = "y", size = { 1.44, 0.3, 1.44 }, at = { -1.344, 1.75, 2.31 }, color = "metal" },
		{ name = "fanGuard1", parent = "base", shape = "cylinder", axis = "y", size = { 1.632, 0.12, 1.632 }, at = { -1.344, 1.94, 2.31 }, color = "dark" },
		{ name = "fan2", parent = "base", shape = "cylinder", axis = "y", size = { 1.44, 0.3, 1.44 }, at = { 1.344, 1.75, 2.31 }, color = "metal" },
		{ name = "fanGuard2", parent = "base", shape = "cylinder", axis = "y", size = { 1.632, 0.12, 1.632 }, at = { 1.344, 1.94, 2.31 }, color = "dark" },
		{ name = "railL", parent = "base", shape = "box", size = { 0.15, 0.4, 5.6 }, at = { -2.4, 1, 0 }, color = "metal" },
		{ name = "railR", parent = "base", shape = "box", size = { 0.15, 0.4, 5.6 }, at = { 2.4, 1, 0 }, color = "metal" },
		{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 1.68, 0.5, 1.68 }, at = { 0, 1.85, 0 }, color = "dark" },
		{ name = "launcher", parent = "turret", shape = "box", size = { 2.4, 1, 2.6 }, at = { 0, 2.6, 0 }, pivot = { 0, 2.6, 0.78 }, color = "hull" },
		{ name = "tube1", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.1 }, at = { -0.72, 2.6, -1.35 }, color = "glass" },
		{ name = "tube2", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.1 }, at = { -0.24, 2.6, -1.35 }, color = "glass" },
		{ name = "tube3", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.1 }, at = { 0.24, 2.6, -1.35 }, color = "glass" },
		{ name = "tube4", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.1 }, at = { 0.72, 2.6, -1.35 }, color = "glass" },
	},
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { 0, 2.6, -1.5 } },
	},
}
