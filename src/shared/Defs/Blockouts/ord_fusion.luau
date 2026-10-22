--!strict
-- Fusion Reactor (Order, T2, footprint 3): a stepped armored block with
-- sloped walls round a glowing cyan containment sphere held in a ring, team
-- plates on the corners. Model space, forward = -Z.

-- footprint 3 -> 4 (size scale, M-26 / S-104): scaled until the redesign lands
return require("./Scale").scaled({
	id = "ord_fusion",
	parts = {
		{ name = "base", shape = "box", size = { 20, 2, 20 }, at = { 0, 1, 0 }, color = "hull" },
		{ name = "wallF", parent = "base", shape = "wedge", size = { 20, 2, 2 }, at = { 0, 1, -11 }, color = "hull" },
		{ name = "wallB", parent = "base", shape = "wedge", size = { 20, 2, 2 }, at = { 0, 1, 11 }, rot = { 0, 180, 0 }, color = "hull" },
		{ name = "wallL", parent = "base", shape = "wedge", size = { 20, 2, 2 }, at = { -11, 1, 0 }, rot = { 0, 90, 0 }, color = "hull" },
		{ name = "wallR", parent = "base", shape = "wedge", size = { 20, 2, 2 }, at = { 11, 1, 0 }, rot = { 0, -90, 0 }, color = "hull" },
		{ name = "block", parent = "base", shape = "box", size = { 14, 2.4, 14 }, at = { 0, 3.2, 0 }, color = "hull" },
		{ name = "ring", parent = "base", shape = "cylinder", axis = "y", size = { 9, 1.2, 9 }, at = { 0, 5, 0 }, color = "metal" },
		{ name = "core", parent = "base", shape = "ball", size = { 6.5, 6.5, 6.5 }, at = { 0, 7.4, 0 }, color = "glass" },
		{ name = "clampA", parent = "base", shape = "box", size = { 0.8, 5, 0.8 }, at = { -4.2, 7.4, 0 }, color = "dark" },
		{ name = "clampB", parent = "base", shape = "box", size = { 0.8, 5, 0.8 }, at = { 4.2, 7.4, 0 }, color = "dark" },
		{ name = "clampTop", parent = "base", shape = "box", size = { 9.2, 0.8, 0.8 }, at = { 0, 10.3, 0 }, color = "dark" },
		{ name = "teamNW", parent = "base", shape = "box", size = { 3, 0.1, 3 }, at = { -5, 4.45, -5 }, color = "team" },
		{ name = "teamNE", parent = "base", shape = "box", size = { 3, 0.1, 3 }, at = { 5, 4.45, -5 }, color = "team" },
		{ name = "teamSW", parent = "base", shape = "box", size = { 3, 0.1, 3 }, at = { -5, 4.45, 5 }, color = "team" },
		{ name = "teamSE", parent = "base", shape = "box", size = { 3, 0.1, 3 }, at = { 5, 4.45, 5 }, color = "team" },
	},
}, 0.724)
