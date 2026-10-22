--!strict
-- Listener (Chaos sonar buoy, T1, footprint 1): two round floats under an
-- open deck frame, a sonar drum hanging between them with a glowing band,
-- a stub lattice post; the T2 Deepear is the four-float platform with a
-- tall mast. Team plate on the deck. Model space, forward = -Z.

return {
	id = "chs_listener",
	parts = {
		{ name = "base", shape = "box", size = { 6, 0.4, 3.6 }, at = { 0, 1.0, 0 }, color = "dark" },
		{ name = "floatL", parent = "base", shape = "cylinder", axis = "z", size = { 1.8, 1.8, 5 }, at = { -2.2, 0.4, 0 }, color = "metal" },
		{ name = "floatR", parent = "base", shape = "cylinder", axis = "z", size = { 1.8, 1.8, 5 }, at = { 2.2, 0.4, 0 }, color = "metal" },
		{ name = "drum", parent = "base", shape = "cylinder", axis = "y", size = { 2.2, 1.4, 2.2 }, at = { 0, 0.4, 0 }, color = "hull", anim = { motion = "turn", axis = { 0, 1, 0 } } },
		{ name = "band", parent = "base", shape = "cylinder", axis = "y", size = { 2.3, 0.25, 2.3 }, at = { 0, 0.85, 0 }, color = "glass" },
		{ name = "team", parent = "base", shape = "box", size = { 1.4, 0.08, 1.4 }, at = { 1.6, 1.24, -1 }, color = "team" },
		{ name = "post", parent = "base", shape = "box", size = { 0.25, 2.2, 0.25 }, at = { -1.6, 2.3, 1.2 }, color = "dark" },
	},
}
