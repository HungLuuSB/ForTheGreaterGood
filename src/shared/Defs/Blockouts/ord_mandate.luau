--!strict
-- Mandate (Order mobile artillery, T2): a long hull with the turret set back and
-- a long howitzer with a recoil sleeve; spades at the rear. Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "ord_mandate",
	parts = {
		{ name = "base", shape = "box", size = { 3.44, 1.1, 9 }, at = { 0, 1.05, 0 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 3.44, 0.88, 1.62 }, at = { 0, 1.16, -5.31 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.08, 1.32, 9.36 }, at = { -2.16, 0.66, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "skirtL", parent = "base", shape = "box", size = { 0.25, 0.77, 8.1 }, at = { -2.82, 1.105, 0 }, color = "hull" },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.08, 1.32, 9.36 }, at = { 2.16, 0.66, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "skirtR", parent = "base", shape = "box", size = { 0.25, 0.77, 8.1 }, at = { 2.82, 1.105, 0 }, color = "hull" },
		{ name = "turret", parent = "base", shape = "box", size = { 3.2, 1.3, 3.6 }, at = { 0, 2.25, 1.8 }, color = "team" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 3.2, 1.3, 1.08 }, at = { 0, 2.25, -0.54 }, color = "team" },
		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 7 }, at = { 0, 2.25, -3.5 }, pivot = { 0, 2.25, 0 }, color = "metal" },
		{ name = "sleeve", parent = "barrel", shape = "cylinder", axis = "z", size = { 0.8, 0.8, 1.6 }, at = { 0, 2.25, -0.8 }, color = "hull" },
		{ name = "spades", parent = "base", shape = "box", size = { 4.6, 0.8, 0.3 }, at = { 0, 0.6, 4.9 }, rot = { 30, 0, 0 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 2.25, -7 } },
	},
}
