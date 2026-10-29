--!strict
-- Advanced Solar Collector (Order, T1, footprint 2; S-209, BAR armadvsol):
-- a generator drum lying across a slab in two cradles, cyan rings on its
-- ends, a mast lifting a big collector panel tilted towards the front,
-- team fins on the corners. Model space, forward = -Z (docs/contracts/rig.md).

return {
	id = "ord_advsolar",
	parts = {
		{ name = "base", shape = "box", size = { 15.6, 0.6, 15.6 }, at = { 0, 0.3, 0 }, color = "hull" },
		{ name = "cradleL", parent = "base", shape = "box", size = { 1.6, 1.8, 4.2 }, at = { -3.6, 1.5, 0.6 }, color = "hull" },
		{ name = "cradleR", parent = "base", shape = "box", size = { 1.6, 1.8, 4.2 }, at = { 3.6, 1.5, 0.6 }, color = "hull" },
		{ name = "drum", parent = "base", shape = "cylinder", axis = "x", size = { 9.2, 4.6, 4.6 }, at = { 0, 3.1, 0.6 }, color = "dark" },
		{ name = "drumTeam", parent = "base", shape = "cylinder", axis = "x", size = { 1.4, 4.8, 4.8 }, at = { 0, 3.1, 0.6 }, color = "team" },
		{ name = "ringL", parent = "base", shape = "cylinder", axis = "x", size = { 0.2, 4.2, 4.2 }, at = { -4.7, 3.1, 0.6 }, color = "glass" },
		{ name = "ringR", parent = "base", shape = "cylinder", axis = "x", size = { 0.2, 4.2, 4.2 }, at = { 4.7, 3.1, 0.6 }, color = "glass" },
		{ name = "mast", parent = "base", shape = "box", size = { 1.2, 2.6, 1.2 }, at = { 0, 6.0, 0.6 }, color = "metal" },
		{ name = "panel", parent = "base", shape = "box", size = { 13.4, 0.3, 7.4 }, at = { 0, 7.6, 0.4 }, rot = { -22, 0, 0 }, color = "dark" },
		{ name = "panelTeam", parent = "base", shape = "box", size = { 13.4, 0.32, 0.4 }, at = { 0, 8.98, 3.82 }, rot = { -22, 0, 0 }, color = "team" },
		{ name = "panelStrip", parent = "base", shape = "box", size = { 13.4, 0.32, 0.3 }, at = { 0, 6.22, -3.0 }, rot = { -22, 0, 0 }, color = "glass" },
		{ name = "finNW", parent = "base", shape = "box", size = { 1.9, 0.9, 1.2 }, at = { -5.9, 1.0, -5.9 }, rot = { 0, 45, 0 }, color = "team" },
		{ name = "finNE", parent = "base", shape = "box", size = { 1.9, 0.9, 1.2 }, at = { 5.9, 1.0, -5.9 }, rot = { 0, -45, 0 }, color = "team" },
		{ name = "finSW", parent = "base", shape = "box", size = { 1.9, 0.9, 1.2 }, at = { -5.9, 1.0, 5.9 }, rot = { 0, -45, 0 }, color = "team" },
		{ name = "finSE", parent = "base", shape = "box", size = { 1.9, 0.9, 1.2 }, at = { 5.9, 1.0, 5.9 }, rot = { 0, 45, 0 }, color = "team" },
	},
}
