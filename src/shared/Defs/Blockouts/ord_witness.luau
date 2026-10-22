--!strict
-- Witness (Order Pinpointer, T2, footprint 2): an armored block with sloped
-- sides and a turning flat phased array on a short mast (the def's `dish`
-- piece; flat panels, never dishes), team plate on the block.
-- Model space, forward = -Z.

return {
	id = "ord_witness",
	parts = {
		{ name = "base", shape = "box", size = { 11, 2.4, 11 }, at = { 0, 1.2, 0 }, color = "hull" },
		{ name = "slopeF", parent = "base", shape = "wedge", size = { 11, 2.4, 1.6 }, at = { 0, 1.2, -6.3 }, color = "hull" },
		{ name = "slopeB", parent = "base", shape = "wedge", size = { 11, 2.4, 1.6 }, at = { 0, 1.2, 6.3 }, rot = { 0, 180, 0 }, color = "hull" },
		{ name = "team", parent = "base", shape = "box", size = { 8, 0.1, 4 }, at = { 0, 2.45, 2.5 }, color = "team" },
		{ name = "mast", parent = "base", shape = "cylinder", axis = "y", size = { 1.4, 2.6, 1.4 }, at = { 0, 3.7, -1 }, color = "dark" },
		{ name = "dish", parent = "base", shape = "box", size = { 7, 3.6, 0.5 }, at = { 0, 6.6, -1 }, rot = { 20, 0, 0 }, pivot = { 0, 5, -1 }, color = "dark", anim = { motion = "turn", axis = { 0, 1, 0 } } },
		{ name = "dishFace", parent = "dish", shape = "box", size = { 6.4, 3, 0.1 }, at = { 0, 6.67, -1.3 }, rot = { 20, 0, 0 }, color = "glass" },
	},
}
