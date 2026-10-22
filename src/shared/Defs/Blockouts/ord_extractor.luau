--!strict
-- Extractor (Order, T1, footprint 1): an armored square housing with sloped
-- sides over the drill shaft, a team plate on top, a cyan ring round the
-- drill head. Model space, forward = -Z (docs/contracts/rig.md).

-- footprint 1 -> 2 (size scale, M-26 / S-104): scaled until the redesign lands
return require("./Scale").scaled({
	id = "ord_extractor",
	parts = {
		{ name = "base", shape = "box", size = { 7.4, 0.5, 7.4 }, at = { 0, 0.25, 0 }, color = "dark" },
		{ name = "housing", parent = "base", shape = "box", size = { 5, 2.4, 5 }, at = { 0, 1.7, 0 }, color = "hull" },
		{ name = "slopeF", parent = "base", shape = "wedge", size = { 5, 1.6, 1.1 }, at = { 0, 1.3, -3.05 }, color = "hull" },
		{ name = "slopeB", parent = "base", shape = "wedge", size = { 5, 1.6, 1.1 }, at = { 0, 1.3, 3.05 }, rot = { 0, 180, 0 }, color = "hull" },
		{ name = "slopeL", parent = "base", shape = "wedge", size = { 5, 1.6, 1.1 }, at = { -3.05, 1.3, 0 }, rot = { 0, 90, 0 }, color = "hull" },
		{ name = "slopeR", parent = "base", shape = "wedge", size = { 5, 1.6, 1.1 }, at = { 3.05, 1.3, 0 }, rot = { 0, -90, 0 }, color = "hull" },
		{ name = "team", parent = "base", shape = "box", size = { 4, 0.1, 4 }, at = { 0, 2.95, 0 }, color = "team" },
		{ name = "drill", parent = "base", shape = "cylinder", axis = "y", size = { 2, 1.6, 2 }, at = { 0, 3.8, 0 }, color = "metal" },
		{ name = "ring", parent = "base", shape = "cylinder", axis = "y", size = { 2.3, 0.25, 2.3 }, at = { 0, 3.4, 0 }, color = "glass" },
		{ name = "cap", parent = "base", shape = "cylinder", axis = "y", size = { 1.4, 0.4, 1.4 }, at = { 0, 4.8, 0 }, color = "dark" },
	},
}, 2.0)
