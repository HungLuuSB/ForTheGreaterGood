--!strict
-- Converter (Order supply converter, T1, footprint 1): an armored block
-- with a glowing coil and cap, side pipes, a team plate.
-- Model space, forward = -Z.

-- footprint 1 -> 2 (size scale, M-26 / S-104): scaled until the redesign lands
return require("./Scale").scaled({
	id = "ord_converter",
	parts = {
		{ name = "base", shape = "box", size = { 6, 1.2, 6 }, at = { 0, 0.6, 0 }, color = "hull" },
		{ name = "housing", parent = "base", shape = "box", size = { 4.4, 2.4, 4.4 }, at = { 0, 2.4, 0 }, color = "hull" },
		{ name = "coil", parent = "base", shape = "cylinder", axis = "y", size = { 2.4, 2, 2.4 }, at = { 0, 4.6, 0 }, color = "glass" },
		{ name = "coilCap", parent = "base", shape = "cylinder", axis = "y", size = { 2.8, 0.4, 2.8 }, at = { 0, 5.8, 0 }, color = "dark" },
		{ name = "team", parent = "base", shape = "box", size = { 3.4, 0.08, 1 }, at = { 0, 3.64, -1.6 }, color = "team" },
		{ name = "pipeL", parent = "base", shape = "box", size = { 0.5, 0.5, 5.6 }, at = { -2.6, 1.5, 0 }, color = "metal" },
		{ name = "pipeR", parent = "base", shape = "box", size = { 0.5, 0.5, 5.6 }, at = { 2.6, 1.5, 0 }, color = "metal" },
	},
}, 2.0)
