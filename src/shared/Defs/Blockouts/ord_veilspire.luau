--!strict
-- Veilspire (Order jammer tower, T2, footprint 1): a tall tapered armored
-- pylon with four cyan emitter fins near the top and a team band.
-- Model space, forward = -Z.

-- footprint 1 -> 2 (size scale, M-26 / S-104): scaled until the redesign lands
return require("./Scale").scaled({
	id = "ord_veilspire",
	parts = {
		{ name = "base", shape = "box", size = { 5.6, 1.2, 5.6 }, at = { 0, 0.6, 0 }, color = "hull" },
		{ name = "pylon", parent = "base", shape = "box", size = { 2.2, 9, 2.2 }, at = { 0, 5.7, 0 }, color = "hull" },
		{ name = "tip", parent = "base", shape = "wedge", size = { 2.2, 2, 2.2 }, at = { 0, 11.2, 0 }, color = "hull" },
		{ name = "band", parent = "base", shape = "box", size = { 2.3, 0.8, 2.3 }, at = { 0, 4, 0 }, color = "team" },
		{ name = "finF", parent = "base", shape = "box", size = { 0.2, 3, 1.4 }, at = { 0, 8.6, -1.8 }, color = "glass" },
		{ name = "finB", parent = "base", shape = "box", size = { 0.2, 3, 1.4 }, at = { 0, 8.6, 1.8 }, color = "glass" },
		{ name = "finL", parent = "base", shape = "box", size = { 1.4, 3, 0.2 }, at = { -1.8, 8.6, 0 }, color = "glass" },
		{ name = "finR", parent = "base", shape = "box", size = { 1.4, 3, 0.2 }, at = { 1.8, 8.6, 0 }, color = "glass" },
	},
}, 2.0)
