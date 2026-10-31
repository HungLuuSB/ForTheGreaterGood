--!strict
-- Luminary (Order mobile tachyon-beam tank, heavy T2): a broad heavy hull and a
-- tall turret carrying a long beam emitter ringed with lenses. Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "ord_luminary",
	parts = {
		{ name = "base", shape = "box", size = { 4.04, 1.3, 9.6 }, at = { 0, 1.15, 0 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 4.04, 1.04, 1.728 }, at = { 0, 1.28, -5.664 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.28, 1.36, 9.984 }, at = { -2.56, 0.68, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "skirtL", parent = "base", shape = "box", size = { 0.25, 0.91, 8.64 }, at = { -3.32, 1.215, 0 }, color = "hull" },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.28, 1.36, 9.984 }, at = { 2.56, 0.68, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "skirtR", parent = "base", shape = "box", size = { 0.25, 0.91, 8.64 }, at = { 3.32, 1.215, 0 }, color = "hull" },
		{ name = "turret", parent = "base", shape = "box", size = { 3.8, 1.4, 4 }, at = { 0, 2.5, 0.8 }, color = "team" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 3.8, 1.4, 1.2 }, at = { 0, 2.5, -1.8 }, color = "team" },
		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 6 }, at = { 0, 2.5, -4.2 }, pivot = { 0, 2.5, -1.2 }, color = "metal" },
		{ name = "lens1", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.1, 1.1, 0.25 }, at = { 0, 2.5, -2.6 }, color = "glass" },
		{ name = "lens2", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.1, 1.1, 0.25 }, at = { 0, 2.5, -4.2 }, color = "glass" },
		{ name = "lens3", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.1, 1.1, 0.25 }, at = { 0, 2.5, -5.8 }, color = "glass" },
		{ name = "capacitor", parent = "turret", shape = "box", size = { 3, 0.9, 1.6 }, at = { 0, 2.7, 3.4 }, color = "hull" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 2.5, -7.2 } },
	},
}
