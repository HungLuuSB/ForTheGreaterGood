--!strict
-- Snapjaw (Chaos hover tank): a skirted hull with a jaw-like split prow and
-- a compact gun turret. Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "chs_snapjaw",
	parts = {
		{ name = "base", shape = "box", size = { 4.8, 0.8, 7 }, at = { 0, 0.4, 0 }, color = "dark" },
		{ name = "bowSkirt", parent = "base", shape = "wedge", size = { 4.8, 0.8, 1.4 }, at = { 0, 0.4, -4.2 }, color = "dark" },
		{ name = "hull", parent = "base", shape = "box", size = { 3.936, 0.9, 5.95 }, at = { 0, 1.25, 0.1 }, color = "hull" },
		{ name = "prow", parent = "base", shape = "wedge", size = { 3.936, 0.9, 1.54 }, at = { 0, 1.25, -3.71 }, color = "hull" },
		{ name = "fan1", parent = "base", shape = "cylinder", axis = "y", size = { 1.44, 0.3, 1.44 }, at = { -1.344, 1.85, 2.31 }, color = "metal" },
		{ name = "fanGuard1", parent = "base", shape = "cylinder", axis = "y", size = { 1.632, 0.12, 1.632 }, at = { -1.344, 2.04, 2.31 }, color = "dark" },
		{ name = "fan2", parent = "base", shape = "cylinder", axis = "y", size = { 1.44, 0.3, 1.44 }, at = { 1.344, 1.85, 2.31 }, color = "metal" },
		{ name = "fanGuard2", parent = "base", shape = "cylinder", axis = "y", size = { 1.632, 0.12, 1.632 }, at = { 1.344, 2.04, 2.31 }, color = "dark" },
		{ name = "railL", parent = "base", shape = "box", size = { 0.15, 0.4, 5.6 }, at = { -2.4, 1, 0 }, color = "metal" },
		{ name = "railR", parent = "base", shape = "box", size = { 0.15, 0.4, 5.6 }, at = { 2.4, 1, 0 }, color = "metal" },
		{ name = "jawL", parent = "base", shape = "wedge", size = { 0.6, 0.7, 1.6 }, at = { -1.6, 1.1, -4 }, color = "metal" },
		{ name = "jawR", parent = "base", shape = "wedge", size = { 0.6, 0.7, 1.6 }, at = { 1.6, 1.1, -4 }, color = "metal" },
		{ name = "turret", parent = "base", shape = "box", size = { 2.4, 0.8, 2.4 }, at = { 0, 2.1, 0 }, color = "hull" },
		{ name = "turretSpike", parent = "turret", shape = "wedge", size = { 1.2, 0.48, 0.96 }, at = { 0, 2.58, -0.48 }, color = "dark" },
		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.32, 0.32, 3 }, at = { 0, 2.1, -2.7 }, pivot = { 0, 2.1, -1.2 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 2.1, -4.2 } },
	},
}
