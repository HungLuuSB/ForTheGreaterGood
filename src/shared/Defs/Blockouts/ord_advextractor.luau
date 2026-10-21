--!strict
-- Advanced Extractor (Order, T2, footprint 1): a taller armored housing with
-- sloped sides, twin drill heads with cyan rings, team plate between them.
-- Model space, forward = -Z.

return {
	id = "ord_advextractor",
	parts = {
		{ name = "base", shape = "box", size = { 7.4, 0.5, 7.4 }, at = { 0, 0.25, 0 }, color = "dark" },
		{ name = "housing", parent = "base", shape = "box", size = { 5.6, 3.4, 5.6 }, at = { 0, 2.2, 0 }, color = "hull" },
		{ name = "slopeF", parent = "base", shape = "wedge", size = { 5.6, 2.2, 0.8 }, at = { 0, 1.6, -3.2 }, color = "hull" },
		{ name = "slopeB", parent = "base", shape = "wedge", size = { 5.6, 2.2, 0.8 }, at = { 0, 1.6, 3.2 }, rot = { 0, 180, 0 }, color = "hull" },
		{ name = "team", parent = "base", shape = "box", size = { 1.6, 0.1, 4.6 }, at = { 0, 3.95, 0 }, color = "team" },
		{ name = "drillL", parent = "base", shape = "cylinder", axis = "y", size = { 1.6, 2.4, 1.6 }, at = { -1.6, 5.1, 0 }, color = "metal" },
		{ name = "drillR", parent = "base", shape = "cylinder", axis = "y", size = { 1.6, 2.4, 1.6 }, at = { 1.6, 5.1, 0 }, color = "metal" },
		{ name = "ringL", parent = "base", shape = "cylinder", axis = "y", size = { 1.9, 0.25, 1.9 }, at = { -1.6, 4.3, 0 }, color = "glass" },
		{ name = "ringR", parent = "base", shape = "cylinder", axis = "y", size = { 1.9, 0.25, 1.9 }, at = { 1.6, 4.3, 0 }, color = "glass" },
	},
}
