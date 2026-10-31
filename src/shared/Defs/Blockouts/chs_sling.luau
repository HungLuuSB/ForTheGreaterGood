--!strict
-- Sling (Chaos hover rocket artillery): a skirted hull with an open rocket
-- rail rack that pitches up to fire. Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "chs_sling",
	parts = {
		{ name = "base", shape = "box", size = { 5, 0.8, 7.6 }, at = { 0, 0.4, 0 }, color = "dark" },
		{ name = "bowSkirt", parent = "base", shape = "wedge", size = { 5, 0.8, 1.52 }, at = { 0, 0.4, -4.56 }, color = "dark" },
		{ name = "hull", parent = "base", shape = "box", size = { 4.1, 0.8, 6.46 }, at = { 0, 1.2, 0.1 }, color = "hull" },
		{ name = "prow", parent = "base", shape = "wedge", size = { 4.1, 0.8, 1.672 }, at = { 0, 1.2, -4.028 }, color = "hull" },
		{ name = "fan1", parent = "base", shape = "cylinder", axis = "y", size = { 1.5, 0.3, 1.5 }, at = { -1.4, 1.75, 2.508 }, color = "metal" },
		{ name = "fanGuard1", parent = "base", shape = "cylinder", axis = "y", size = { 1.7, 0.12, 1.7 }, at = { -1.4, 1.94, 2.508 }, color = "dark" },
		{ name = "fan2", parent = "base", shape = "cylinder", axis = "y", size = { 1.5, 0.3, 1.5 }, at = { 1.4, 1.75, 2.508 }, color = "metal" },
		{ name = "fanGuard2", parent = "base", shape = "cylinder", axis = "y", size = { 1.7, 0.12, 1.7 }, at = { 1.4, 1.94, 2.508 }, color = "dark" },
		{ name = "railL", parent = "base", shape = "box", size = { 0.15, 0.4, 6.08 }, at = { -2.5, 1, 0 }, color = "metal" },
		{ name = "railR", parent = "base", shape = "box", size = { 0.15, 0.4, 6.08 }, at = { 2.5, 1, 0 }, color = "metal" },
		{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 2.1, 0.5, 2.1 }, at = { 0, 1.85, 0.2 }, color = "dark" },
		{ name = "launcher", parent = "turret", shape = "box", size = { 3, 1.4, 3.2 }, at = { 0, 2.8, 0.2 }, pivot = { 0, 2.8, 1.16 }, color = "hull" },
		{ name = "tube1", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 0.1 }, at = { -0.8, 2.8, -1.45 }, color = "glass" },
		{ name = "tube2", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 0.1 }, at = { 0, 2.8, -1.45 }, color = "glass" },
		{ name = "tube3", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 0.1 }, at = { 0.8, 2.8, -1.45 }, color = "glass" },
	},
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { 0, 2.8, -1.6 } },
	},
}
