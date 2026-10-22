--!strict
-- Ear (Order sonar buoy, T1, footprint 1): a small armored floating pad
-- with a squat sonar housing and a glowing ring, a short whip mast; the T2
-- Choir is the same idea three times the size with a tall mast and panel.
-- Team plate on the pad. Model space, forward = -Z.

return {
	id = "ord_ear",
	parts = {
		{ name = "base", shape = "box", size = { 6, 1.2, 6 }, at = { 0, 0.3, 0 }, color = "hull" },
		{ name = "ring", parent = "base", shape = "cylinder", axis = "y", size = { 3.6, 0.25, 3.6 }, at = { 0, 1.0, 0 }, color = "glass" },
		{ name = "housing", parent = "base", shape = "cylinder", axis = "y", size = { 3, 1.2, 3 }, at = { 0, 1.7, 0 }, color = "hull" },
		{ name = "team", parent = "base", shape = "box", size = { 1.6, 0.1, 1.6 }, at = { -2, 0.95, 2 }, color = "team" },
		{ name = "mast", parent = "base", shape = "box", size = { 0.25, 2.4, 0.25 }, at = { 1.8, 2.1, 1.8 }, color = "dark" },
	},
}
