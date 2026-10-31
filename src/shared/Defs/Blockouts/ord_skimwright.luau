--!strict
-- Skimwright (Order hover constructor): a broad skirted hull with a cab
-- and a constructor arm (`nano`). Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "ord_skimwright",
	parts = {
		{ name = "base", shape = "box", size = { 5, 0.8, 7 }, at = { 0, 0.4, 0 }, color = "dark" },
		{ name = "bowSkirt", parent = "base", shape = "wedge", size = { 5, 0.8, 1.4 }, at = { 0, 0.4, -4.2 }, color = "dark" },
		{ name = "hull", parent = "base", shape = "box", size = { 4.1, 0.9, 5.95 }, at = { 0, 1.25, 0.1 }, color = "hull" },
		{ name = "prow", parent = "base", shape = "wedge", size = { 4.1, 0.9, 1.54 }, at = { 0, 1.25, -3.71 }, color = "hull" },
		{ name = "fan1", parent = "base", shape = "cylinder", axis = "y", size = { 1.5, 0.3, 1.5 }, at = { -1.4, 1.85, 2.31 }, color = "metal" },
		{ name = "fanGuard1", parent = "base", shape = "cylinder", axis = "y", size = { 1.7, 0.12, 1.7 }, at = { -1.4, 2.04, 2.31 }, color = "dark" },
		{ name = "fan2", parent = "base", shape = "cylinder", axis = "y", size = { 1.5, 0.3, 1.5 }, at = { 1.4, 1.85, 2.31 }, color = "metal" },
		{ name = "fanGuard2", parent = "base", shape = "cylinder", axis = "y", size = { 1.7, 0.12, 1.7 }, at = { 1.4, 2.04, 2.31 }, color = "dark" },
		{ name = "stripe", parent = "base", shape = "box", size = { 2.05, 0.06, 2.1 }, at = { 0, 1.73, -0.84 }, color = "team" },
		{ name = "cab", parent = "base", shape = "box", size = { 2, 1.1, 1.8 }, at = { -1.1, 2.25, -1.5 }, color = "hull" },
		{ name = "cabGlass", parent = "base", shape = "box", size = { 1.6, 0.4, 0.1 }, at = { -1.1, 2.45, -2.42 }, color = "glass" },
		{ name = "nano", parent = "base", shape = "cylinder", axis = "y", size = { 1.4, 0.5, 1.4 }, at = { 1, 1.95, 0.2 }, color = "dark" },
		{ name = "boom", parent = "nano", shape = "box", size = { 0.5, 0.5, 3 }, at = { 1, 2.7, -1.3 }, rot = { -20, 0, 0 }, color = "team" },
		{ name = "emitter", parent = "nano", shape = "ball", size = { 0.7, 0.7, 0.7 }, at = { 1, 3.25, -2.8 }, color = "glass" },
	},
	attachments = {
		{ name = "nano1", parent = "nano", at = { 1, 3.25, -3.1 } },
	},
}
