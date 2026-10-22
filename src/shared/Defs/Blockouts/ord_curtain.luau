--!strict
-- Curtain (Order jammer, T1, footprint 1): a squat armored block with a short
-- tapered emitter post and two glowing fins; the T2 Veilspire is the tall
-- pylon with four fins. Team band on the block. Model space, forward = -Z.

return {
	id = "ord_curtain",
	parts = {
		{ name = "base", shape = "box", size = { 5, 1.6, 5 }, at = { 0, 0.8, 0 }, color = "hull" },
		{ name = "team", parent = "base", shape = "box", size = { 3.6, 0.1, 1.2 }, at = { 0, 1.65, 1.5 }, color = "team" },
		{ name = "post", parent = "base", shape = "box", size = { 1.4, 3.2, 1.4 }, at = { 0, 3.2, -0.4 }, color = "hull" },
		{ name = "tip", parent = "base", shape = "wedge", size = { 1.4, 1, 1.4 }, at = { 0, 5.3, -0.4 }, color = "hull" },
		{ name = "finL", parent = "base", shape = "box", size = { 1.2, 2, 0.2 }, at = { -1.3, 3.6, -0.4 }, color = "glass" },
		{ name = "finR", parent = "base", shape = "box", size = { 1.2, 2, 0.2 }, at = { 1.3, 3.6, -0.4 }, color = "glass" },
	},
}
