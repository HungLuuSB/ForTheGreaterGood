--!strict
-- Behemoth (Chaos strategic bomber, T2, footprint 1): the biggest Chaos
-- delta, an armored belly, chaff boxes on the pods, a bomb `bay` and a
-- `pylon` rail. Model space, forward = -Z.

return {
	id = "chs_behemoth",
	parts = {
		{ name = "base", shape = "cylinder", axis = "z", size = { 1.3, 1.3, 8.6 }, at = { 0, 0.7, 0 }, color = "hull" },
		{ name = "nose", parent = "base", shape = "wedge", size = { 1.2, 1, 1.8 }, at = { 0, 0.65, -5.2 }, color = "hull" },
		{ name = "canopy", parent = "base", shape = "ball", size = { 0.8, 0.6, 1.4 }, at = { 0, 1.35, -3 }, color = "glass" },
		{ name = "delta", parent = "base", shape = "wedge", size = { 8, 0.2, 4.4 }, at = { 0, 0.5, 1 }, color = "hull" },
		{ name = "deltaTeam", parent = "base", shape = "box", size = { 4, 0.06, 1 }, at = { 0, 0.62, 2.4 }, color = "team" },
		{ name = "canardL", parent = "base", shape = "box", size = { 1.6, 0.12, 0.7 }, at = { -1.1, 0.9, -2.7 }, color = "dark" },
		{ name = "canardR", parent = "base", shape = "box", size = { 1.6, 0.12, 0.7 }, at = { 1.1, 0.9, -2.7 }, color = "dark" },
		{ name = "tail", parent = "base", shape = "box", size = { 0.18, 1.9, 1.8 }, at = { 0, 2, 3.4 }, color = "team" },
		{ name = "podL", parent = "base", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 2.4 }, at = { -1, 0.45, 3.3 }, color = "metal" },
		{ name = "podR", parent = "base", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 2.4 }, at = { 1, 0.45, 3.3 }, color = "metal" },
		{ name = "glowL", parent = "base", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 0.2 }, at = { -1, 0.45, 4.55 }, color = "glass" },
		{ name = "glowR", parent = "base", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 0.2 }, at = { 1, 0.45, 4.55 }, color = "glass" },
		{ name = "armorBelly", parent = "base", shape = "box", size = { 1.8, 0.4, 4.4 }, at = { 0, 0.15, 0.2 }, color = "dark" },
		{ name = "chaffL", parent = "base", shape = "box", size = { 0.4, 0.4, 1 }, at = { -1.6, 0.9, 2.6 }, color = "metal" },
		{ name = "chaffR", parent = "base", shape = "box", size = { 0.4, 0.4, 1 }, at = { 1.6, 0.9, 2.6 }, color = "metal" },
		{ name = "pylon", parent = "base", shape = "box", size = { 5.6, 0.25, 0.8 }, at = { 0, 0.3, 1.6 }, color = "dark" },
		{ name = "bay", parent = "base", shape = "box", size = { 1.2, 0.2, 2.6 }, at = { 0, 0.1, 0.2 }, color = "dark" },
		{ name = "bayLip", parent = "bay", shape = "box", size = { 1.4, 0.1, 0.2 }, at = { 0, 0.05, -1.1 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "bay", at = { 0, -0.1, 0.2 } },
	},
}
