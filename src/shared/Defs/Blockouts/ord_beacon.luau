--!strict
-- Beacon (Order long-range radar, T2, footprint 3): a stepped armored base
-- and a tall square tower with a team band, carrying a very wide flat
-- phased array (visual piece `radar`) with a cyan face. Model space,
-- forward = -Z.

return {
	id = "ord_beacon",
	visualPieces = { "radar" },
	parts = {
		{ name = "base", shape = "box", size = { 18, 1.6, 18 }, at = { 0, 0.8, 0 }, color = "hull" },
		{ name = "wallF", parent = "base", shape = "wedge", size = { 18, 1.6, 2 }, at = { 0, 0.8, -10 }, color = "hull" },
		{ name = "wallB", parent = "base", shape = "wedge", size = { 18, 1.6, 2 }, at = { 0, 0.8, 10 }, rot = { 0, 180, 0 }, color = "hull" },
		{ name = "plinth", parent = "base", shape = "box", size = { 9, 2, 9 }, at = { 0, 2.6, 0 }, color = "hull" },
		{ name = "team", parent = "base", shape = "box", size = { 7, 0.1, 7 }, at = { 0, 3.65, 0 }, color = "team" },
		{ name = "tower", parent = "base", shape = "box", size = { 3.4, 12, 3.4 }, at = { 0, 9.6, 0 }, color = "hull" },
		{ name = "band", parent = "base", shape = "box", size = { 3.5, 1, 3.5 }, at = { 0, 13, 0 }, color = "team" },
		{ name = "light", parent = "base", shape = "box", size = { 0.5, 0.5, 0.1 }, at = { 0, 6, -1.75 }, color = "glass" },
		{ name = "radar", parent = "base", shape = "box", size = { 12, 5, 0.6 }, at = { 0, 17.6, 0 }, rot = { 15, 0, 0 }, pivot = { 0, 15.6, 0 }, color = "dark", anim = { motion = "turn", axis = { 0, 1, 0 } } },
		{ name = "radarFace", parent = "radar", shape = "box", size = { 11, 4.2, 0.12 }, at = { 0, 17.68, -0.36 }, rot = { 15, 0, 0 }, color = "glass" },
	},
}
