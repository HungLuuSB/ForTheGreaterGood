--!strict
-- Hoard (Chaos storage, T1, footprint 1): a cluster of round tanks of
-- different sizes on an open frame, a pipe across them, a team plate on the
-- biggest tank, an orange light. Model space, forward = -Z
-- (docs/contracts/rig.md).

-- footprint 1 -> 2 (size scale, M-26 / S-104): scaled until the redesign lands
return require("./Scale").scaled({
	id = "chs_depot",
	parts = {
		{ name = "base", shape = "box", size = { 6.6, 0.4, 6.6 }, at = { 0, 0.2, 0 }, color = "dark" },
		{ name = "tankA", parent = "base", shape = "cylinder", axis = "y", size = { 3.2, 3.2, 3.2 }, at = { -1.4, 2, -1.2 }, color = "hull" },
		{ name = "tankB", parent = "base", shape = "cylinder", axis = "y", size = { 2.4, 2.4, 2.4 }, at = { 1.8, 1.6, -1.4 }, color = "hull" },
		{ name = "tankC", parent = "base", shape = "cylinder", axis = "z", size = { 2, 2, 4 }, at = { 0.6, 1.4, 2 }, color = "metal" },
		{ name = "team", parent = "base", shape = "cylinder", axis = "y", size = { 2.4, 0.1, 2.4 }, at = { -1.4, 3.65, -1.2 }, color = "team" },
		{ name = "pipe", parent = "base", shape = "cylinder", axis = "x", size = { 4, 0.4, 0.4 }, at = { 0.2, 2.9, -1.3 }, color = "dark" },
		{ name = "light", parent = "base", shape = "box", size = { 0.4, 0.4, 0.4 }, at = { 1.8, 3, -1.4 }, color = "glass" },
	},
}, 2.0)
