--!strict
-- Furnace (Chaos generator, T1, footprint 1): two round combustion tanks of
-- different heights on an open frame, an orange glowing band on each, a
-- team plate on the platform. Model space, forward = -Z
-- (docs/contracts/rig.md).

-- footprint 1 -> 2 (size scale, M-26 / S-104): scaled until the redesign lands
return require("./Scale").scaled({
	id = "chs_generator",
	parts = {
		{ name = "base", shape = "box", size = { 6.6, 0.5, 6.6 }, at = { 0, 0.25, 0 }, color = "dark" },
		{ name = "tankA", parent = "base", shape = "cylinder", axis = "y", size = { 3.2, 4.6, 3.2 }, at = { -1.3, 2.8, 0.6 }, color = "hull" },
		{ name = "tankB", parent = "base", shape = "cylinder", axis = "y", size = { 2.6, 3.2, 2.6 }, at = { 1.7, 2.1, 1.2 }, color = "hull" },
		{ name = "glowA", parent = "base", shape = "cylinder", axis = "y", size = { 3.3, 0.3, 3.3 }, at = { -1.3, 3.6, 0.6 }, color = "glass" },
		{ name = "glowB", parent = "base", shape = "cylinder", axis = "y", size = { 2.7, 0.3, 2.7 }, at = { 1.7, 2.6, 1.2 }, color = "glass" },
		{ name = "capA", parent = "base", shape = "cylinder", axis = "y", size = { 2.2, 0.4, 2.2 }, at = { -1.3, 5.3, 0.6 }, color = "metal" },
		{ name = "frameF", parent = "base", shape = "box", size = { 6, 0.3, 0.3 }, at = { 0, 3.9, -1.4 }, color = "dark" },
		{ name = "postL", parent = "base", shape = "box", size = { 0.3, 3.6, 0.3 }, at = { -2.8, 2.2, -1.4 }, color = "dark" },
		{ name = "postR", parent = "base", shape = "box", size = { 0.3, 3.6, 0.3 }, at = { 2.8, 2.2, -1.4 }, color = "dark" },
		{ name = "team", parent = "base", shape = "box", size = { 4.6, 0.08, 1.2 }, at = { 0, 0.54, -2.4 }, color = "team" },
	},
}, 2.0)
