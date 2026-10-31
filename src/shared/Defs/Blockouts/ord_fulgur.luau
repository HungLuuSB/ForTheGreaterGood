--!strict
-- Fulgur (Order lightning tank with an anti-air missile, T2): a turret with a
-- lightning coil on top and a small missile box at its side. Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "ord_fulgur",
	parts = {
		{ name = "base", shape = "box", size = { 3.44, 1.1, 8.2 }, at = { 0, 1.05, 0 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 3.44, 0.88, 1.476 }, at = { 0, 1.16, -4.838 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.08, 1.32, 8.528 }, at = { -2.16, 0.66, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "skirtL", parent = "base", shape = "box", size = { 0.25, 0.77, 7.38 }, at = { -2.82, 1.105, 0 }, color = "hull" },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.08, 1.32, 8.528 }, at = { 2.16, 0.66, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "skirtR", parent = "base", shape = "box", size = { 0.25, 0.77, 7.38 }, at = { 2.82, 1.105, 0 }, color = "hull" },
		{ name = "turret", parent = "base", shape = "box", size = { 3.2, 0.9, 3.4 }, at = { 0, 2.05, 0.3 }, color = "team" },
		{ name = "barrel", parent = "turret", shape = "box", size = { 1.2, 0.3, 1.2 }, at = { 0, 2.65, -0.2 }, pivot = { 0, 2.65, -0.2 }, color = "dark" },
		{ name = "coil1", parent = "barrel", shape = "cylinder", axis = "y", size = { 0.5, 2, 0.5 }, at = { 0, 3.8, -0.2 }, color = "metal" },
		{ name = "coil1Ring1", parent = "barrel", shape = "cylinder", axis = "y", size = { 0.8, 0.15, 0.8 }, at = { 0, 3.4, -0.2 }, color = "glass" },
		{ name = "coil1Ring2", parent = "barrel", shape = "cylinder", axis = "y", size = { 0.8, 0.15, 0.8 }, at = { 0, 3.9, -0.2 }, color = "glass" },
		{ name = "coil1Ring3", parent = "barrel", shape = "cylinder", axis = "y", size = { 0.8, 0.15, 0.8 }, at = { 0, 4.4, -0.2 }, color = "glass" },
		{ name = "coil1Top", parent = "barrel", shape = "ball", size = { 0.9, 0.9, 0.9 }, at = { 0, 5.1, -0.2 }, color = "glass" },
		{ name = "missileBox", parent = "turret", shape = "box", size = { 0.8, 0.8, 1.8 }, at = { 1.9, 2.6, 0.4 }, color = "hull" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 5.3, -0.2 } },
		{ name = "aa_muzzle", parent = "turret", at = { 1.9, 2.6, -0.6 } },
	},
}
