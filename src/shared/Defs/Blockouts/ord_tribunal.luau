--!strict
-- Tribunal (Order fire-control radar, T2, footprint 2): an armored block
-- carrying two tall flat panels back to back (visual piece `radar`), a team
-- band, cyan faces. Model space, forward = -Z.

return {
	id = "ord_tribunal",
	visualPieces = { "radar" },
	parts = {
		{ name = "base", shape = "box", size = { 13, 1.2, 13 }, at = { 0, 0.6, 0 }, color = "hull" },
		{ name = "wallF", parent = "base", shape = "wedge", size = { 13, 1.2, 1.4 }, at = { 0, 0.6, -7.2 }, color = "hull" },
		{ name = "block", parent = "base", shape = "box", size = { 7, 3, 7 }, at = { 0, 2.7, 0 }, color = "hull" },
		{ name = "team", parent = "base", shape = "box", size = { 6, 0.1, 6 }, at = { 0, 4.25, 0 }, color = "team" },
		{ name = "mast", parent = "base", shape = "cylinder", axis = "y", size = { 1.2, 2.4, 1.2 }, at = { 0, 5.4, 0 }, color = "dark" },
		{ name = "radar", parent = "base", shape = "box", size = { 6, 5, 0.6 }, at = { 0, 9.1, 0 }, pivot = { 0, 6.6, 0 }, color = "dark", anim = { motion = "turn", axis = { 0, 1, 0 } } },
		{ name = "faceF", parent = "radar", shape = "box", size = { 5.4, 4.4, 0.1 }, at = { 0, 9.1, -0.36 }, color = "glass" },
		{ name = "faceB", parent = "radar", shape = "box", size = { 5.4, 4.4, 0.1 }, at = { 0, 9.1, 0.36 }, color = "glass" },
	},
}
