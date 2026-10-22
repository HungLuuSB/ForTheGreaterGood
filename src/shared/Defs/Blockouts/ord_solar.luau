--!strict
-- Solar Array (Order, T1, footprint 1): one large flat panel tilted toward
-- the sun on a solid pedestal, a cyan edge strip, team plate on the base.
-- Model space, forward = -Z (docs/contracts/rig.md).

-- footprint 1 -> 2 (size scale, M-26 / S-104): scaled until the redesign lands
return require("./Scale").scaled({
	id = "ord_solar",
	parts = {
		{ name = "base", shape = "box", size = { 7.4, 0.6, 7.4 }, at = { 0, 0.3, 0 }, color = "hull" },
		{ name = "team", parent = "base", shape = "box", size = { 6, 0.08, 1.4 }, at = { 0, 0.64, 2.8 }, color = "team" },
		{ name = "pedestal", parent = "base", shape = "box", size = { 1.6, 1.8, 1.6 }, at = { 0, 1.5, 0 }, color = "metal" },
		{ name = "panel", parent = "base", shape = "box", size = { 7, 0.25, 5.6 }, at = { 0, 2.7, 0 }, rot = { -25, 0, 0 }, color = "dark" },
		{ name = "frame", parent = "base", shape = "box", size = { 7.2, 0.15, 0.3 }, at = { 0, 3.88, 2.55 }, rot = { -25, 0, 0 }, color = "hull" },
		{ name = "strip", parent = "base", shape = "box", size = { 7.2, 0.15, 0.2 }, at = { 0, 1.55, -2.5 }, rot = { -25, 0, 0 }, color = "glass" },
	},
}, 2.0)
