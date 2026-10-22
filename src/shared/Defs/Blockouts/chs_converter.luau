--!strict
-- Converter (Chaos supply converter, T1, footprint 1): a tank with a
-- glowing band, exposed pipework and a stack on a skid.
-- Model space, forward = -Z.

-- footprint 1 -> 2 (size scale, M-26 / S-104): scaled until the redesign lands
return require("./Scale").scaled({
	id = "chs_converter",
	parts = {
		{ name = "base", shape = "box", size = { 6, 0.5, 6 }, at = { 0, 0.25, 0 }, color = "dark" },
		{ name = "tank", parent = "base", shape = "cylinder", axis = "y", size = { 3.6, 3, 3.6 }, at = { 0, 2, 0.6 }, color = "metal" },
		{ name = "glowBand", parent = "base", shape = "cylinder", axis = "y", size = { 3.7, 0.3, 3.7 }, at = { 0, 2.6, 0.6 }, color = "glass" },
		{ name = "team", parent = "base", shape = "box", size = { 2.4, 0.08, 1 }, at = { 0, 0.54, -2.2 }, color = "team" },
		{ name = "pipeA", parent = "base", shape = "box", size = { 0.4, 2.6, 0.4 }, at = { -2.2, 1.8, -1.6 }, color = "dark" },
		{ name = "pipeB", parent = "base", shape = "box", size = { 2.6, 0.4, 0.4 }, at = { -1, 3.1, -1.6 }, color = "dark" },
		{ name = "stack", parent = "base", shape = "cylinder", axis = "y", size = { 0.5, 2.4, 0.5 }, at = { 2.2, 2.2, -1.8 }, color = "dark" },
	},
}, 2.0)
