--!strict
-- Tidal (Order tidal generator, T1, footprint 1): a floating armored pad, a
-- round housing with a glowing ring, a turbine under the water.
-- Model space, forward = -Z.

-- footprint 1 -> 2 (size scale, M-26 / S-104): scaled until the redesign lands
return require("./Scale").scaled({
	id = "ord_tidal",
	parts = {
		{ name = "base", shape = "box", size = { 6, 1, 6 }, at = { 0, 0.2, 0 }, color = "hull" },
		{ name = "housing", parent = "base", shape = "cylinder", axis = "y", size = { 3, 1.6, 3 }, at = { 0, 1.5, 0 }, color = "hull" },
		{ name = "team", parent = "base", shape = "box", size = { 2, 0.08, 1 }, at = { 0, 0.74, -2.3 }, color = "team" },
		{ name = "ring", parent = "base", shape = "cylinder", axis = "y", size = { 3.2, 0.25, 3.2 }, at = { 0, 0.9, 0 }, color = "glass" },
		{ name = "turbine", parent = "base", shape = "cylinder", axis = "z", size = { 2.4, 0.6, 2.4 }, at = { 0, -0.6, 0 }, color = "metal" },
	},
}, 2.0)
