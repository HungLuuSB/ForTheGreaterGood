--!strict
-- Gnat (Chaos fast light hover raider): a tiny dart of a hull, one fan, a
-- light gun. Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "chs_gnat",
	parts = {
		{ name = "base", shape = "box", size = { 3.4, 0.8, 5 }, at = { 0, 0.4, 0 }, color = "dark" },
		{ name = "bowSkirt", parent = "base", shape = "wedge", size = { 3.4, 0.8, 1 }, at = { 0, 0.4, -3 }, color = "dark" },
		{ name = "hull", parent = "base", shape = "box", size = { 2.788, 0.6, 4.25 }, at = { 0, 1.1, 0.1 }, color = "hull" },
		{ name = "prow", parent = "base", shape = "wedge", size = { 2.788, 0.6, 1.1 }, at = { 0, 1.1, -2.65 }, color = "hull" },
		{ name = "fan1", parent = "base", shape = "cylinder", axis = "y", size = { 1.02, 0.3, 1.02 }, at = { 0, 1.55, 1.65 }, color = "metal" },
		{ name = "fanGuard1", parent = "base", shape = "cylinder", axis = "y", size = { 1.156, 0.12, 1.156 }, at = { 0, 1.74, 1.65 }, color = "dark" },
		{ name = "railL", parent = "base", shape = "box", size = { 0.15, 0.4, 4 }, at = { -1.7, 1, 0 }, color = "metal" },
		{ name = "railR", parent = "base", shape = "box", size = { 0.15, 0.4, 4 }, at = { 1.7, 1, 0 }, color = "metal" },
		{ name = "turret", parent = "base", shape = "box", size = { 1.4, 0.6, 1.6 }, at = { 0, 1.7, -0.5 }, color = "hull" },
		{ name = "turretSpike", parent = "turret", shape = "wedge", size = { 0.7, 0.36, 0.64 }, at = { 0, 2.06, -0.82 }, color = "dark" },
		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.2, 0.2, 2.2 }, at = { 0, 1.7, -2.4 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "turret", at = { 0, 1.7, -3.5 } },
	},
}
