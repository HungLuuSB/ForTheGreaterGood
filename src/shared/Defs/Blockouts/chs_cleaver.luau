--!strict
-- Cleaver (Chaos riot tank, T1): a short angular hull and a squat turret with a
-- wide, stubby scatter gun. Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "chs_cleaver",
	parts = {
		{ name = "base", shape = "box", size = { 2.96, 1, 6.4 }, at = { 0, 1, 0 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 2.96, 0.8, 1.152 }, at = { 0, 1.1, -3.776 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 0.92, 1.3, 6.656 }, at = { -1.84, 0.65, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "cageL", parent = "base", shape = "box", size = { 0.12, 0.12, 5.44 }, at = { -2.36, 1.15, 0 }, color = "metal" },
		{ name = "trackR", parent = "base", shape = "box", size = { 0.92, 1.3, 6.656 }, at = { 1.84, 0.65, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "cageR", parent = "base", shape = "box", size = { 0.12, 0.12, 5.44 }, at = { 2.36, 1.15, 0 }, color = "metal" },
		{ name = "turret", parent = "base", shape = "box", size = { 2.6, 0.9, 2.4 }, at = { 0, 1.95, 0.5 }, color = "hull" },
		{ name = "turretSpike", parent = "turret", shape = "wedge", size = { 1.3, 0.54, 0.96 }, at = { 0, 2.49, 0.02 }, color = "dark" },
		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 1.8 }, at = { 0, 1.95, -1.6 }, pivot = { 0, 1.95, -0.7 }, color = "metal" },
		{ name = "flare", parent = "barrel", shape = "cylinder", axis = "z", size = { 1, 1, 0.4 }, at = { 0, 1.95, -3.2 }, color = "dark" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 1.95, -2.5 } },
	},
}
