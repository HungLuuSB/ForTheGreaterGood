--!strict
-- Grendel (Chaos very heavy amphibious tank, T2): a broad boat-bowed hull with
-- heavy floats, a massive turret and a short heavy gun. Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "chs_grendel",
	parts = {
		{ name = "base", shape = "box", size = { 4.4, 1.6, 10 }, at = { 0, 1.3, 0 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 4.4, 1.28, 1.8 }, at = { 0, 1.46, -5.9 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.4, 1.42, 10.4 }, at = { -2.8, 0.71, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "cageL", parent = "base", shape = "box", size = { 0.12, 0.12, 8.5 }, at = { -3.56, 1.6, 0 }, color = "metal" },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.4, 1.42, 10.4 }, at = { 2.8, 0.71, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "cageR", parent = "base", shape = "box", size = { 0.12, 0.12, 8.5 }, at = { 3.56, 1.6, 0 }, color = "metal" },
		{ name = "bow", parent = "base", shape = "wedge", size = { 6.6, 1.76, 3 }, at = { 0, 1.4, -6.2 }, color = "hull" },
		{ name = "floatL", parent = "base", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 7 }, at = { -3.85, 1.56, 0.2 }, color = "dark" },
		{ name = "floatR", parent = "base", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 7 }, at = { 3.85, 1.56, 0.2 }, color = "dark" },
		{ name = "snorkel", parent = "base", shape = "cylinder", axis = "y", size = { 0.35, 1.6, 0.35 }, at = { 2.1, 2.9, 3.8 }, color = "metal" },
		{ name = "turret", parent = "base", shape = "box", size = { 4.4, 1.5, 4 }, at = { 0, 2.85, 0.8 }, color = "hull" },
		{ name = "turretSpike", parent = "turret", shape = "wedge", size = { 2.2, 0.9, 1.6 }, at = { 0, 3.75, 0 }, color = "dark" },
		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.8, 0.8, 4.4 }, at = { 0, 2.85, -3.4 }, pivot = { 0, 2.85, -1.2 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 2.85, -5.6 } },
	},
}
