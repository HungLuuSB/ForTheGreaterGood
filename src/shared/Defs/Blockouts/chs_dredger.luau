--!strict
-- Dredger (Chaos amphibious constructor, T1): the amphibious hull with an open
-- cab and a constructor arm (`nano`) ending in a claw. Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "chs_dredger",
	parts = {
		{ name = "base", shape = "box", size = { 3.08, 1.1, 7 }, at = { 0, 1.05, 0 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 3.08, 0.88, 1.26 }, at = { 0, 1.16, -4.13 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 0.96, 1.32, 7.28 }, at = { -1.92, 0.66, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "cageL", parent = "base", shape = "box", size = { 0.12, 0.12, 5.95 }, at = { -2.46, 1.225, 0 }, color = "metal" },
		{ name = "trackR", parent = "base", shape = "box", size = { 0.96, 1.32, 7.28 }, at = { 1.92, 0.66, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "cageR", parent = "base", shape = "box", size = { 0.12, 0.12, 5.95 }, at = { 2.46, 1.225, 0 }, color = "metal" },
		{ name = "bow", parent = "base", shape = "wedge", size = { 4.4, 1.21, 2.1 }, at = { 0, 1.15, -4.34 }, color = "hull" },
		{ name = "floatL", parent = "base", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 4.9 }, at = { -2.75, 1.26, 0.2 }, color = "dark" },
		{ name = "floatR", parent = "base", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 4.9 }, at = { 2.75, 1.26, 0.2 }, color = "dark" },
		{ name = "snorkel", parent = "base", shape = "cylinder", axis = "y", size = { 0.35, 1.6, 0.35 }, at = { 1.44, 2.4, 2.66 }, color = "metal" },
		{ name = "cab", parent = "base", shape = "box", size = { 1.8, 1, 1.6 }, at = { -1.1, 2.1, -1.7 }, color = "hull" },
		{ name = "nano", parent = "base", shape = "cylinder", axis = "y", size = { 1.4, 0.5, 1.4 }, at = { 0.9, 1.85, 1 }, color = "dark" },
		{ name = "boom", parent = "nano", shape = "box", size = { 0.5, 0.5, 3.4 }, at = { 0.9, 2.6, -0.7 }, rot = { -20, 0, 0 }, color = "hull" },
		{ name = "emitter", parent = "nano", shape = "ball", size = { 0.7, 0.7, 0.7 }, at = { 0.9, 3.15, -2.4 }, color = "glass" },
		{ name = "claw", parent = "nano", shape = "wedge", size = { 0.9, 0.9, 0.6 }, at = { 0.9, 2.7, -2.7 }, color = "metal" },
	},
	attachments = {
		{ name = "nano1", parent = "nano", at = { 0.9, 3.15, -2.7 } },
	},
}
