--!strict
-- Sun Trap (Chaos solar, T1, footprint 1): three smaller panels at uneven
-- tilts on an open frame, an orange status light, a team plate on the base.
-- Model space, forward = -Z (docs/contracts/rig.md).

-- footprint 1 -> 2 (size scale, M-26 / S-104): scaled until the redesign lands
return require("./Scale").scaled({
	id = "chs_solar",
	parts = {
		{ name = "base", shape = "box", size = { 6.6, 0.4, 6.6 }, at = { 0, 0.2, 0 }, color = "dark" },
		{ name = "team", parent = "base", shape = "box", size = { 2.4, 0.08, 2.4 }, at = { 2, 0.44, 2 }, color = "team" },
		{ name = "rail", parent = "base", shape = "box", size = { 6, 0.3, 0.3 }, at = { 0, 1.6, 0 }, color = "dark" },
		{ name = "postL", parent = "base", shape = "box", size = { 0.3, 1.4, 0.3 }, at = { -2.6, 0.9, 0 }, color = "dark" },
		{ name = "postR", parent = "base", shape = "box", size = { 0.3, 1.4, 0.3 }, at = { 2.6, 0.9, 0 }, color = "dark" },
		{ name = "panelA", parent = "base", shape = "box", size = { 2, 0.15, 3.4 }, at = { -2.1, 2.1, -0.6 }, rot = { -30, 0, 0 }, color = "hull" },
		{ name = "panelB", parent = "base", shape = "box", size = { 2, 0.15, 3.4 }, at = { 0, 2.2, -0.6 }, rot = { -20, 0, 4 }, color = "hull" },
		{ name = "panelC", parent = "base", shape = "box", size = { 2, 0.15, 3.4 }, at = { 2.1, 2.05, -0.6 }, rot = { -35, 0, -3 }, color = "hull" },
		{ name = "light", parent = "base", shape = "box", size = { 0.4, 0.4, 0.4 }, at = { -2.6, 1.8, 0.6 }, color = "glass" },
	},
}, 2.0)
