--!strict
-- Architect (Order advanced builder, T2, footprint 1): the Mason grown up:
-- a heavier tracked hull with skirts and a dozer blade, a raised cab, and on
-- the `nano` turntable twin booms carrying two glowing emitters (the T1
-- Mason has one). Team plates on the turntable and the counterweight.
-- Model space, forward = -Z.

return {
	id = "ord_architect",
	parts = {
		{ name = "base", shape = "box", size = { 5.4, 1.4, 7.0 }, at = { 0, 1.6, 0.4 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 5.4, 1.4, 1.2 }, at = { 0, 1.6, -3.7 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.1, 1.3, 8.0 }, at = { -2.8, 0.65, 0 }, color = "track" },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.1, 1.3, 8.0 }, at = { 2.8, 0.65, 0 }, color = "track" },
		{ name = "skirtL", parent = "base", shape = "box", size = { 0.35, 1.1, 7.4 }, at = { -3.5, 1.15, 0 }, color = "hull" },
		{ name = "skirtR", parent = "base", shape = "box", size = { 0.35, 1.1, 7.4 }, at = { 3.5, 1.15, 0 }, color = "hull" },
		{ name = "blade", parent = "base", shape = "box", size = { 6.6, 1.2, 0.35 }, at = { 0, 0.9, -4.8 }, rot = { -12, 0, 0 }, color = "metal" },
		{ name = "cab", parent = "base", shape = "box", size = { 3.4, 1.2, 1.6 }, at = { 0, 2.9, -1.9 }, color = "hull" },
		{ name = "windshield", parent = "base", shape = "wedge", size = { 3.4, 1.2, 0.8 }, at = { 0, 2.9, -3.1 }, color = "glass" },

		{ name = "nano", parent = "base", shape = "cylinder", axis = "y", size = { 3.0, 0.5, 3.0 }, at = { 0, 2.55, 1.9 }, color = "team" },
		{ name = "boomL", parent = "nano", shape = "box", size = { 0.7, 0.7, 4.4 }, at = { -0.8, 4.1, 0.6 }, rot = { 35, 0, 0 }, color = "hull" },
		{ name = "boomR", parent = "nano", shape = "box", size = { 0.7, 0.7, 4.4 }, at = { 0.8, 4.1, 0.6 }, rot = { 35, 0, 0 }, color = "hull" },
		{ name = "emitterL", parent = "nano", shape = "ball", size = { 1.0, 1.0, 1.0 }, at = { -0.8, 5.4, -1.4 }, color = "glass" },
		{ name = "emitterR", parent = "nano", shape = "ball", size = { 1.0, 1.0, 1.0 }, at = { 0.8, 5.4, -1.4 }, color = "glass" },
		{ name = "counterweight", parent = "nano", shape = "box", size = { 2.4, 1.0, 1.0 }, at = { 0, 3.3, 3.1 }, color = "team" },
	},
}
