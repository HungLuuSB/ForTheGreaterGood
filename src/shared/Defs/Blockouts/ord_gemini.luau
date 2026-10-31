--!strict
-- Gemini (Order twin rocket-launcher tank, T1): a tracked hull with a turret
-- carrying two rocket boxes side by side (the `launcher` pitches). Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "ord_gemini",
	parts = {
		{ name = "base", shape = "box", size = { 3.08, 1, 7 }, at = { 0, 1, 0 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 3.08, 0.8, 1.26 }, at = { 0, 1.1, -4.13 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 0.96, 1.3, 7.28 }, at = { -1.92, 0.65, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "skirtL", parent = "base", shape = "box", size = { 0.25, 0.7, 6.3 }, at = { -2.52, 1.05, 0 }, color = "hull" },
		{ name = "trackR", parent = "base", shape = "box", size = { 0.96, 1.3, 7.28 }, at = { 1.92, 0.65, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "skirtR", parent = "base", shape = "box", size = { 0.25, 0.7, 6.3 }, at = { 2.52, 1.05, 0 }, color = "hull" },
		{ name = "turret", parent = "base", shape = "box", size = { 3, 0.8, 3 }, at = { 0, 1.9, 0.4 }, color = "hull" },
		{ name = "launcher", parent = "turret", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { 0, 2.9, 0.4 }, pivot = { 0, 2.9, 0.6 }, color = "dark" },
		{ name = "podL", parent = "launcher", shape = "box", size = { 1.3, 1.1, 2.8 }, at = { -1, 2.9, 0.2 }, color = "team" },
		{ name = "podLFace", parent = "launcher", shape = "box", size = { 1, 0.8, 0.1 }, at = { -1, 2.9, -1.25 }, color = "glass" },
		{ name = "podR", parent = "launcher", shape = "box", size = { 1.3, 1.1, 2.8 }, at = { 1, 2.9, 0.2 }, color = "team" },
		{ name = "podRFace", parent = "launcher", shape = "box", size = { 1, 0.8, 0.1 }, at = { 1, 2.9, -1.25 }, color = "glass" },
	},
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { -1, 2.9, -1.4 } },
		{ name = "muzzle2", parent = "launcher", at = { 1, 2.9, -1.4 } },
	},
}
