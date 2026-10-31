--!strict
-- Wader (Order light amphibious tank, T1): a boat-bowed tracked hull with
-- flotation sponsons and a snorkel, a small turret and gun. Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "ord_wader",
	parts = {
		{ name = "base", shape = "box", size = { 2.96, 1.1, 6.8 }, at = { 0, 1.05, 0 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 2.96, 0.88, 1.224 }, at = { 0, 1.16, -4.012 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 0.92, 1.32, 7.072 }, at = { -1.84, 0.66, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "skirtL", parent = "base", shape = "box", size = { 0.25, 0.77, 6.12 }, at = { -2.42, 1.105, 0 }, color = "hull" },
		{ name = "trackR", parent = "base", shape = "box", size = { 0.92, 1.32, 7.072 }, at = { 1.84, 0.66, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "skirtR", parent = "base", shape = "box", size = { 0.25, 0.77, 6.12 }, at = { 2.42, 1.105, 0 }, color = "hull" },
		{ name = "bow", parent = "base", shape = "wedge", size = { 4.2, 1.21, 2.04 }, at = { 0, 1.15, -4.216 }, color = "hull" },
		{ name = "floatL", parent = "base", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 4.76 }, at = { -2.65, 1.26, 0.2 }, color = "team" },
		{ name = "floatR", parent = "base", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 4.76 }, at = { 2.65, 1.26, 0.2 }, color = "team" },
		{ name = "snorkel", parent = "base", shape = "cylinder", axis = "y", size = { 0.35, 1.6, 0.35 }, at = { 1.38, 2.4, 2.584 }, color = "metal" },
		{ name = "turret", parent = "base", shape = "box", size = { 2.4, 0.8, 2.4 }, at = { 0, 2, 0.6 }, color = "team" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 2.4, 0.8, 0.72 }, at = { 0, 2, -0.96 }, color = "team" },
		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 2.8 }, at = { 0, 2, -2 }, pivot = { 0, 2, -0.6 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 2, -3.4 } },
	},
}
