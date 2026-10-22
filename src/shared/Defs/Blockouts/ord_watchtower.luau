--!strict
-- Watchtower (Order radar tower, T1, footprint 1): a tall square armored
-- tower with a team band, carrying a wide flat phased-array panel (visual
-- piece `radar`, turned by a piece script) with a cyan face.
-- Model space, forward = -Z (docs/contracts/rig.md).

return {
	id = "ord_watchtower",
	visualPieces = { "radar" },
	parts = {
		{ name = "base", shape = "box", size = { 6, 1, 6 }, at = { 0, 0.5, 0 }, color = "hull" },
		{ name = "plinth", parent = "base", shape = "wedge", size = { 6, 1.2, 1.2 }, at = { 0, 1.6, -2.4 }, color = "hull" },
		{ name = "tower", parent = "base", shape = "box", size = { 2.4, 8, 2.4 }, at = { 0, 5, 0 }, color = "hull" },
		{ name = "band", parent = "base", shape = "box", size = { 2.5, 0.8, 2.5 }, at = { 0, 7.6, 0 }, color = "team" },
		{ name = "light", parent = "base", shape = "box", size = { 0.4, 0.4, 0.1 }, at = { 0, 3, -1.25 }, color = "glass" },
		{ name = "radar", parent = "base", shape = "box", size = { 5.6, 2.8, 0.4 }, at = { 0, 10.2, 0 }, rot = { 15, 0, 0 }, pivot = { 0, 9, 0 }, color = "dark", anim = { motion = "turn", axis = { 0, 1, 0 } } },
		{ name = "radarFace", parent = "radar", shape = "box", size = { 5, 2.3, 0.1 }, at = { 0, 10.25, -0.24 }, rot = { 15, 0, 0 }, color = "glass" },
	},
}
