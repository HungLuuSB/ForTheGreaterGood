--!strict
-- Advanced Vehicle Plant (Order factory, T2, footprint 5): two armored halls
-- side by side under one roof, two doors over ramps, team roof plates, cyan
-- light strips, sloped buttresses. Model space, forward = -Z.

-- footprint 5 -> 6 (size scale, M-26 / S-104): scaled until the redesign lands
return require("./Scale").scaled({
	id = "ord_advvehplant",
	parts = {
		{ name = "base", shape = "box", size = { 38, 0.6, 38 }, at = { 0, 0.3, 0 }, color = "dark" },
		{ name = "hall", parent = "base", shape = "box", size = { 32, 8, 22 }, at = { 0, 4.6, 5 }, color = "hull" },
		{ name = "roofEdge", parent = "base", shape = "wedge", size = { 32, 1.6, 2 }, at = { 0, 9.4, -5 }, color = "hull" },
		{ name = "roof", parent = "base", shape = "box", size = { 32, 1.6, 20 }, at = { 0, 9.4, 6 }, color = "hull" },
		{ name = "teamL", parent = "base", shape = "box", size = { 12, 0.12, 14 }, at = { -8, 10.26, 6 }, color = "team" },
		{ name = "teamR", parent = "base", shape = "box", size = { 12, 0.12, 14 }, at = { 8, 10.26, 6 }, color = "team" },
		{ name = "doorL", parent = "base", shape = "box", size = { 11, 6, 0.3 }, at = { -8, 3.6, -6.1 }, color = "dark" },
		{ name = "doorR", parent = "base", shape = "box", size = { 11, 6, 0.3 }, at = { 8, 3.6, -6.1 }, color = "dark" },
		{ name = "lightL", parent = "base", shape = "box", size = { 11, 0.3, 0.12 }, at = { -8, 7.0, -6.3 }, color = "glass" },
		{ name = "lightR", parent = "base", shape = "box", size = { 11, 0.3, 0.12 }, at = { 8, 7.0, -6.3 }, color = "glass" },
		{ name = "rampL", parent = "base", shape = "wedge", size = { 12, 0.6, 6 }, at = { -8, 0.9, -9.2 }, color = "metal" },
		{ name = "rampR", parent = "base", shape = "wedge", size = { 12, 0.6, 6 }, at = { 8, 0.9, -9.2 }, color = "metal" },
		{ name = "pillar", parent = "base", shape = "wedge", size = { 3, 8, 3 }, at = { 0, 4.6, -7.5 }, color = "hull" },
		{ name = "buttressL", parent = "base", shape = "wedge", size = { 4, 6, 4 }, at = { -18, 3.6, -4 }, rot = { 0, 90, 0 }, color = "hull" },
		{ name = "buttressR", parent = "base", shape = "wedge", size = { 4, 6, 4 }, at = { 18, 3.6, -4 }, rot = { 0, -90, 0 }, color = "hull" },
		{ name = "vents", parent = "base", shape = "box", size = { 10, 1.2, 4 }, at = { 0, 10.8, 13 }, color = "metal" },
	},
	-- nanoframe anchors (M-25, rig.md 8)
	attachments = {
		{ name = "buildpad", parent = "base", at = { -8, 0.6, -11 } },
		{ name = "nano1", parent = "base", at = { -13.3, 6.8, -6.4 } },
		{ name = "nano2", parent = "base", at = { -2.7, 6.8, -6.4 } },
		{ name = "nano3", parent = "base", at = { -8, 7, -6.4 } },
	},
}, 1.14)
