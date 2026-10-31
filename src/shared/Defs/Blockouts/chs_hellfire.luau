--!strict
-- Hellfire (Chaos heavy missile tank, T2): a heavy angular hull with a big
-- armoured missile box (`launcher`) on a low turret. Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "chs_hellfire",
	parts = {
		{ name = "base", shape = "box", size = { 3.68, 1.2, 8.6 }, at = { 0, 1.1, 0 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 3.68, 0.96, 1.548 }, at = { 0, 1.22, -5.074 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.16, 1.34, 8.944 }, at = { -2.32, 0.67, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "cageL", parent = "base", shape = "box", size = { 0.12, 0.12, 7.31 }, at = { -2.96, 1.3, 0 }, color = "metal" },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.16, 1.34, 8.944 }, at = { 2.32, 0.67, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "cageR", parent = "base", shape = "box", size = { 0.12, 0.12, 7.31 }, at = { 2.96, 1.3, 0 }, color = "metal" },
		{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 2.8, 0.5, 2.8 }, at = { 0, 1.95, 0.6 }, color = "dark" },
		{ name = "launcher", parent = "turret", shape = "box", size = { 4, 1.8, 3.4 }, at = { 0, 3.1, 0.6 }, pivot = { 0, 3.1, 1.62 }, color = "hull" },
		{ name = "tube1", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.4, 0.4, 0.1 }, at = { -1.333, 3.1, -1.15 }, color = "glass" },
		{ name = "tube2", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.4, 0.4, 0.1 }, at = { -0.8, 3.1, -1.15 }, color = "glass" },
		{ name = "tube3", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.4, 0.4, 0.1 }, at = { -0.267, 3.1, -1.15 }, color = "glass" },
		{ name = "tube4", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.4, 0.4, 0.1 }, at = { 0.267, 3.1, -1.15 }, color = "glass" },
		{ name = "tube5", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.4, 0.4, 0.1 }, at = { 0.8, 3.1, -1.15 }, color = "glass" },
		{ name = "tube6", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.4, 0.4, 0.1 }, at = { 1.333, 3.1, -1.15 }, color = "glass" },
	},
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { 0, 3.1, -1.3 } },
	},
}
