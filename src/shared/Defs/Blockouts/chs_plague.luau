--!strict
-- Plague (Chaos bomber, T1, footprint 1): the Chaos delta with a fat belly,
-- a bomb `bay` and an under-wing `pylon` rail for carpet bombs.
-- Model space, forward = -Z.

return {
	id = "chs_plague",
	parts = {
		{ name = "base", shape = "cylinder", axis = "z", size = { 1.3, 1.3, 7.6 }, at = { 0, 0.7, 0 }, color = "hull" },
		{ name = "nose", parent = "base", shape = "wedge", size = { 1.2, 1, 1.8 }, at = { 0, 0.65, -4.7 }, color = "hull" },
		{ name = "canopy", parent = "base", shape = "ball", size = { 0.8, 0.6, 1.4 }, at = { 0, 1.35, -2.5 }, color = "glass" },
		{ name = "delta", parent = "base", shape = "wedge", size = { 7.6, 0.2, 4.4 }, at = { 0, 0.5, 1 }, color = "hull" },
		{ name = "deltaTeam", parent = "base", shape = "box", size = { 3.8, 0.06, 1 }, at = { 0, 0.62, 2.4 }, color = "team" },
		{ name = "canardL", parent = "base", shape = "box", size = { 1.6, 0.12, 0.7 }, at = { -1.1, 0.9, -2.2 }, color = "dark" },
		{ name = "canardR", parent = "base", shape = "box", size = { 1.6, 0.12, 0.7 }, at = { 1.1, 0.9, -2.2 }, color = "dark" },
		{ name = "tail", parent = "base", shape = "box", size = { 0.18, 1.9, 1.8 }, at = { 0, 2, 2.9 }, color = "team" },
		{ name = "podL", parent = "base", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 2.4 }, at = { -1, 0.45, 2.8 }, color = "metal" },
		{ name = "podR", parent = "base", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 2.4 }, at = { 1, 0.45, 2.8 }, color = "metal" },
		{ name = "glowL", parent = "base", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 0.2 }, at = { -1, 0.45, 4.05 }, color = "glass" },
		{ name = "glowR", parent = "base", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 0.2 }, at = { 1, 0.45, 4.05 }, color = "glass" },
		{ name = "pylon", parent = "base", shape = "box", size = { 4.6, 0.25, 0.8 }, at = { 0, 0.3, 1.4 }, color = "dark" },
		{ name = "bay", parent = "base", shape = "box", size = { 1.2, 0.2, 2.6 }, at = { 0, 0.1, 0.2 }, color = "dark" },
		{ name = "bayLip", parent = "bay", shape = "box", size = { 1.4, 0.1, 0.2 }, at = { 0, 0.05, -1.1 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "bay", at = { 0, -0.1, 0.2 } },
	},
}
