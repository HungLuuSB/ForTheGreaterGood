--!strict
-- Airpad (Chaos rearm pad, T1, footprint 3): a grated apron with a landing
-- circle ringed in team color, fuel tanks with a hose, a lattice light
-- mast. Model space, forward = -Z.

return {
	id = "chs_airpad",
	parts = {
		{ name = "base", shape = "box", size = { 22, 0.6, 22 }, at = { 0, 0.3, 0 }, color = "dark" },
		{ name = "pad", parent = "base", shape = "cylinder", axis = "y", size = { 14, 0.2, 14 }, at = { 0, 0.7, 0 }, color = "dark" },
		{ name = "ring", parent = "base", shape = "cylinder", axis = "y", size = { 14.4, 0.15, 14.4 }, at = { 0, 0.66, 0 }, color = "team" },
		{ name = "markA", parent = "base", shape = "box", size = { 0.6, 0.06, 6 }, at = { -1.6, 0.83, 0 }, color = "hull" },
		{ name = "markB", parent = "base", shape = "box", size = { 0.6, 0.06, 6 }, at = { 1.6, 0.83, 0 }, color = "hull" },
		{ name = "markC", parent = "base", shape = "box", size = { 3.2, 0.06, 0.6 }, at = { 0, 0.83, 0 }, color = "hull" },
		{ name = "light0", parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { -9, 0.85, -9 }, color = "glass" },
		{ name = "light1", parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { 9, 0.85, -9 }, color = "glass" },
		{ name = "light2", parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { -9, 0.85, 9 }, color = "glass" },
		{ name = "light3", parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { 9, 0.85, 9 }, color = "glass" },
		{ name = "tankA", parent = "base", shape = "cylinder", axis = "y", size = { 2.4, 2.6, 2.4 }, at = { 8.6, 1.9, -7.6 }, color = "metal" },
		{ name = "tankB", parent = "base", shape = "cylinder", axis = "y", size = { 2.4, 2.6, 2.4 }, at = { 8.6, 1.9, -4.6 }, color = "metal" },
		{ name = "hose", parent = "base", shape = "box", size = { 0.25, 0.25, 6 }, at = { 6.4, 0.9, -3 }, color = "dark" },
		{ name = "mast", parent = "base", shape = "box", size = { 0.25, 5, 0.25 }, at = { -9.6, 3.1, 9.6 }, color = "dark" },
		{ name = "mastLight", parent = "base", shape = "box", size = { 0.4, 0.4, 0.4 }, at = { -9.6, 5.8, 9.6 }, color = "glass" },
	},
}
