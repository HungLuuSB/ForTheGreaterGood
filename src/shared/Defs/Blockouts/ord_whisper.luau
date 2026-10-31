--!strict
-- Whisper (Order cloaked tank, T2): low and faceted, a flat wedge turret with
-- no hard edges and a shrouded gun; the hull sides are angled plates. Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "ord_whisper",
	parts = {
		{ name = "base", shape = "box", size = { 3.32, 0.9, 8 }, at = { 0, 0.95, 0 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 3.32, 0.72, 1.44 }, at = { 0, 1.04, -4.72 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.04, 1.28, 8.32 }, at = { -2.08, 0.64, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "skirtL", parent = "base", shape = "box", size = { 0.25, 0.63, 7.2 }, at = { -2.72, 0.995, 0 }, color = "hull" },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.04, 1.28, 8.32 }, at = { 2.08, 0.64, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "skirtR", parent = "base", shape = "box", size = { 0.25, 0.63, 7.2 }, at = { 2.72, 0.995, 0 }, color = "hull" },
		{ name = "facetL", parent = "base", shape = "wedge", size = { 1.4, 0.8, 7 }, at = { -2, 1.3, 0 }, rot = { 0, 0, 90 }, color = "dark" },
		{ name = "facetR", parent = "base", shape = "wedge", size = { 1.4, 0.8, 7 }, at = { 2, 1.3, 0 }, rot = { 0, 0, -90 }, color = "dark" },
		{ name = "turret", parent = "base", shape = "wedge", size = { 3.2, 0.7, 3.8 }, at = { 0, 1.75, 0.2 }, color = "team" },
		{ name = "turretBack", parent = "turret", shape = "box", size = { 3.2, 0.7, 1 }, at = { 0, 1.75, 2.5 }, color = "team" },
		{ name = "barrel", parent = "turret", shape = "box", size = { 0.6, 0.45, 4 }, at = { 0, 1.75, -3.3 }, pivot = { 0, 1.75, -1.6 }, color = "dark" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 1.75, -5.3 } },
	},
}
