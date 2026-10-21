--!strict
-- Choir (Order sonar station, T2, footprint 3): a floating armored platform
-- with sloped sides, a central housing over the sonar array (a cyan ring at
-- the waterline), a mast with a flat panel, team plates on the deck.
-- Model space, forward = -Z.

return {
	id = "ord_choir",
	parts = {
		{ name = "base", shape = "box", size = { 18, 1.6, 18 }, at = { 0, 0.4, 0 }, color = "hull" },
		{ name = "wallF", parent = "base", shape = "wedge", size = { 18, 1.6, 2 }, at = { 0, 0.4, -10 }, color = "hull" },
		{ name = "wallB", parent = "base", shape = "wedge", size = { 18, 1.6, 2 }, at = { 0, 0.4, 10 }, rot = { 0, 180, 0 }, color = "hull" },
		{ name = "ring", parent = "base", shape = "cylinder", axis = "y", size = { 10, 0.3, 10 }, at = { 0, 1.35, 0 }, color = "glass" },
		{ name = "housing", parent = "base", shape = "cylinder", axis = "y", size = { 8, 2.4, 8 }, at = { 0, 2.6, 0 }, color = "hull" },
		{ name = "teamA", parent = "base", shape = "box", size = { 3, 0.1, 3 }, at = { -6, 1.25, -6 }, color = "team" },
		{ name = "teamB", parent = "base", shape = "box", size = { 3, 0.1, 3 }, at = { 6, 1.25, 6 }, color = "team" },
		{ name = "mast", parent = "base", shape = "box", size = { 0.8, 5, 0.8 }, at = { 0, 6.3, 0 }, color = "dark" },
		{ name = "panel", parent = "base", shape = "box", size = { 3.4, 2, 0.3 }, at = { 0, 9.6, 0 }, rot = { 15, 0, 0 }, color = "dark" },
	},
}
