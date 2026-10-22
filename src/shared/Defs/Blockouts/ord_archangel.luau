--!strict
-- Archangel (Order AWACS, T2, footprint 1): a long Order jet carrying the
-- `dish`: a flat plank radar (a panel, never a dish) on two struts along
-- the spine, glowing on both faces. Unarmed. Model space, forward = -Z.

return {
	id = "ord_archangel",
	parts = {
		{ name = "base", shape = "box", size = { 1.6, 0.9, 8.6 }, at = { 0, 0.6, 0 }, color = "hull" },
		{ name = "nose", parent = "base", shape = "wedge", size = { 1.6, 0.9, 1.6 }, at = { 0, 0.6, -5.1 }, color = "hull" },
		{ name = "canopy", parent = "base", shape = "wedge", size = { 0.8, 0.45, 1.6 }, at = { 0, 1.25, -2.9 }, color = "glass" },
		{ name = "wingL", parent = "base", shape = "wedge", size = { 3, 0.2, 3.2 }, at = { -2.3, 0.45, 0.6 }, rot = { 0, -90, 0 }, color = "hull" },
		{ name = "wingR", parent = "base", shape = "wedge", size = { 3, 0.2, 3.2 }, at = { 2.3, 0.45, 0.6 }, rot = { 0, 90, 0 }, color = "hull" },
		{ name = "wingTeamL", parent = "base", shape = "box", size = { 1.2, 0.06, 1 }, at = { -2.5, 0.6, 1 }, color = "team" },
		{ name = "wingTeamR", parent = "base", shape = "box", size = { 1.2, 0.06, 1 }, at = { 2.5, 0.6, 1 }, color = "team" },
		{ name = "tailL", parent = "base", shape = "box", size = { 0.15, 1.3, 1.4 }, at = { -0.6, 1.55, 3.5 }, rot = { 0, 0, -15 }, color = "team" },
		{ name = "tailR", parent = "base", shape = "box", size = { 0.15, 1.3, 1.4 }, at = { 0.6, 1.55, 3.5 }, rot = { 0, 0, 15 }, color = "team" },
		{ name = "engineL", parent = "base", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 0.3 }, at = { -0.45, 0.6, 4.4 }, color = "glass" },
		{ name = "engineR", parent = "base", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 0.3 }, at = { 0.45, 0.6, 4.4 }, color = "glass" },
		{ name = "strutF", parent = "base", shape = "box", size = { 0.25, 0.8, 0.25 }, at = { 0, 1.4, -0.8 }, color = "dark" },
		{ name = "strutB", parent = "base", shape = "box", size = { 0.25, 0.8, 0.25 }, at = { 0, 1.4, 1.4 }, color = "dark" },
		{ name = "dish", parent = "base", shape = "box", size = { 0.5, 0.5, 5.2 }, at = { 0, 2, 0.3 }, color = "hull" },
		{ name = "dishFaceL", parent = "dish", shape = "box", size = { 0.06, 0.35, 4.8 }, at = { -0.27, 2, 0.3 }, color = "glass" },
		{ name = "dishFaceR", parent = "dish", shape = "box", size = { 0.06, 0.35, 4.8 }, at = { 0.27, 2, 0.3 }, color = "glass" },
	},
}
