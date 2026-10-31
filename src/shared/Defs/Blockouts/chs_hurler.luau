--!strict
-- Hurler (Chaos mobile artillery, T2): an open-frame hull with the gun set far
-- back on a short turret, a long howitzer and rear spades. Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "chs_hurler",
	parts = {
		{ name = "base", shape = "box", size = { 3.44, 1, 9 }, at = { 0, 1, 0 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 3.44, 0.8, 1.62 }, at = { 0, 1.1, -5.31 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.08, 1.3, 9.36 }, at = { -2.16, 0.65, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "cageL", parent = "base", shape = "box", size = { 0.12, 0.12, 7.65 }, at = { -2.76, 1.15, 0 }, color = "metal" },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.08, 1.3, 9.36 }, at = { 2.16, 0.65, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "cageR", parent = "base", shape = "box", size = { 0.12, 0.12, 7.65 }, at = { 2.76, 1.15, 0 }, color = "metal" },
		{ name = "turret", parent = "base", shape = "box", size = { 2.8, 1.1, 3 }, at = { 0, 2.05, 2.2 }, color = "hull" },
		{ name = "turretSpike", parent = "turret", shape = "wedge", size = { 1.4, 0.66, 1.2 }, at = { 0, 2.71, 1.6 }, color = "dark" },
		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 7.2 }, at = { 0, 2.05, -2.9 }, pivot = { 0, 2.05, 0.7 }, color = "metal" },
		{ name = "spades", parent = "base", shape = "box", size = { 4.6, 0.8, 0.3 }, at = { 0, 0.6, 4.9 }, rot = { 30, 0, 0 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 2.05, -6.5 } },
	},
}
