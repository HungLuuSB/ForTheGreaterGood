--!strict
-- Courser (Order fast light assault tank, T1): a low, narrow wedge on light tracks,
-- a small flat turret and a short quick gun. Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "ord_courser",
	parts = {
		{ name = "base", shape = "box", size = { 2.6, 0.9, 6.4 }, at = { 0, 0.95, 0 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 2.6, 0.72, 1.152 }, at = { 0, 1.04, -3.776 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 0.9, 1.28, 6.656 }, at = { -1.65, 0.64, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "skirtL", parent = "base", shape = "box", size = { 0.25, 0.63, 5.76 }, at = { -2.22, 0.995, 0 }, color = "hull" },
		{ name = "trackR", parent = "base", shape = "box", size = { 0.9, 1.28, 6.656 }, at = { 1.65, 0.64, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "skirtR", parent = "base", shape = "box", size = { 0.25, 0.63, 5.76 }, at = { 2.22, 0.995, 0 }, color = "hull" },
		{ name = "turret", parent = "base", shape = "box", size = { 2.4, 0.8, 2.6 }, at = { 0, 1.8, 0.4 }, color = "team" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 2.4, 0.8, 0.78 }, at = { 0, 1.8, -1.29 }, color = "team" },
		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.32, 0.32, 3.2 }, at = { 0, 1.8, -2.5 }, pivot = { 0, 1.8, -0.9 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 1.8, -4.1 } },
	},
}
