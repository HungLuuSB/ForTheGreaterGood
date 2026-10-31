--!strict
-- Drifter (Chaos hover constructor): a skirted open-frame hull with a
-- constructor arm (`nano`). Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "chs_drifter",
	parts = {
		{ name = "base", shape = "box", size = { 5, 0.8, 7 }, at = { 0, 0.4, 0 }, color = "dark" },
		{ name = "bowSkirt", parent = "base", shape = "wedge", size = { 5, 0.8, 1.4 }, at = { 0, 0.4, -4.2 }, color = "dark" },
		{ name = "hull", parent = "base", shape = "box", size = { 4.1, 0.8, 5.95 }, at = { 0, 1.2, 0.1 }, color = "hull" },
		{ name = "prow", parent = "base", shape = "wedge", size = { 4.1, 0.8, 1.54 }, at = { 0, 1.2, -3.71 }, color = "hull" },
		{ name = "fan1", parent = "base", shape = "cylinder", axis = "y", size = { 1.5, 0.3, 1.5 }, at = { -1.4, 1.75, 2.31 }, color = "metal" },
		{ name = "fanGuard1", parent = "base", shape = "cylinder", axis = "y", size = { 1.7, 0.12, 1.7 }, at = { -1.4, 1.94, 2.31 }, color = "dark" },
		{ name = "fan2", parent = "base", shape = "cylinder", axis = "y", size = { 1.5, 0.3, 1.5 }, at = { 1.4, 1.75, 2.31 }, color = "metal" },
		{ name = "fanGuard2", parent = "base", shape = "cylinder", axis = "y", size = { 1.7, 0.12, 1.7 }, at = { 1.4, 1.94, 2.31 }, color = "dark" },
		{ name = "railL", parent = "base", shape = "box", size = { 0.15, 0.4, 5.6 }, at = { -2.5, 1, 0 }, color = "metal" },
		{ name = "railR", parent = "base", shape = "box", size = { 0.15, 0.4, 5.6 }, at = { 2.5, 1, 0 }, color = "metal" },
		{ name = "nano", parent = "base", shape = "cylinder", axis = "y", size = { 1.4, 0.5, 1.4 }, at = { 0.6, 1.85, 0 }, color = "dark" },
		{ name = "boom", parent = "nano", shape = "box", size = { 0.5, 0.5, 3.4 }, at = { 0.6, 2.6, -1.7 }, rot = { -20, 0, 0 }, color = "hull" },
		{ name = "emitter", parent = "nano", shape = "ball", size = { 0.7, 0.7, 0.7 }, at = { 0.6, 3.15, -3.4 }, color = "glass" },
	},
	attachments = {
		{ name = "nano1", parent = "nano", at = { 0.6, 3.15, -3.7 } },
	},
}
