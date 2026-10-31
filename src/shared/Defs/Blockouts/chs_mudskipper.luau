--!strict
-- Mudskipper (Chaos light amphibious tank, T1): a low boat-bowed hull with open
-- side floats, a small turret and gun. Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "chs_mudskipper",
	parts = {
		{ name = "base", shape = "box", size = { 2.8, 1, 6.6 }, at = { 0, 1, 0 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 2.8, 0.8, 1.188 }, at = { 0, 1.1, -3.894 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 0.9, 1.3, 6.864 }, at = { -1.75, 0.65, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "cageL", parent = "base", shape = "box", size = { 0.12, 0.12, 5.61 }, at = { -2.26, 1.15, 0 }, color = "metal" },
		{ name = "trackR", parent = "base", shape = "box", size = { 0.9, 1.3, 6.864 }, at = { 1.75, 0.65, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "cageR", parent = "base", shape = "box", size = { 0.12, 0.12, 5.61 }, at = { 2.26, 1.15, 0 }, color = "metal" },
		{ name = "bow", parent = "base", shape = "wedge", size = { 4, 1.1, 1.98 }, at = { 0, 1.1, -4.092 }, color = "hull" },
		{ name = "floatL", parent = "base", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 4.62 }, at = { -2.55, 1.2, 0.2 }, color = "dark" },
		{ name = "floatR", parent = "base", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 4.62 }, at = { 2.55, 1.2, 0.2 }, color = "dark" },
		{ name = "snorkel", parent = "base", shape = "cylinder", axis = "y", size = { 0.35, 1.6, 0.35 }, at = { 1.32, 2.3, 2.508 }, color = "metal" },
		{ name = "turret", parent = "base", shape = "box", size = { 2.2, 0.8, 2.2 }, at = { 0, 1.9, 0.6 }, color = "hull" },
		{ name = "turretSpike", parent = "turret", shape = "wedge", size = { 1.1, 0.48, 0.88 }, at = { 0, 2.38, 0.16 }, color = "dark" },
		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 2.8 }, at = { 0, 1.9, -1.9 }, pivot = { 0, 1.9, -0.5 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 1.9, -3.3 } },
	},
}
