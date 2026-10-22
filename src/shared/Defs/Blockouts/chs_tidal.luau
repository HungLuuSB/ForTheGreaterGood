--!strict
-- Tidal (Chaos tidal generator, T1, footprint 1): two floats under a deck with
-- an exposed water rotor between them. Model space, forward = -Z.

-- footprint 1 -> 2 (size scale, M-26 / S-104): scaled until the redesign lands
return require("./Scale").scaled({
	id = "chs_tidal",
	parts = {
		{ name = "base", shape = "box", size = { 5.6, 0.4, 3.2 }, at = { 0, 0.8, 0 }, color = "dark" },
		{ name = "floatL", parent = "base", shape = "cylinder", axis = "z", size = { 1.4, 1.4, 5.4 }, at = { -2, 0.3, 0 }, color = "metal" },
		{ name = "floatR", parent = "base", shape = "cylinder", axis = "z", size = { 1.4, 1.4, 5.4 }, at = { 2, 0.3, 0 }, color = "metal" },
		{ name = "rotor", parent = "base", shape = "cylinder", axis = "x", size = { 2.6, 0.3, 2.6 }, at = { 0, -0.3, 0 }, color = "hull" },
		{ name = "team", parent = "base", shape = "box", size = { 1.6, 0.08, 1 }, at = { 0, 1.04, 0 }, color = "team" },
		{ name = "light", parent = "base", shape = "box", size = { 0.4, 0.4, 0.4 }, at = { 2, 1.2, 2.4 }, color = "glass" },
	},
}, 2.0)
