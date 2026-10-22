--!strict
-- Absolution (Order bomber, T1, footprint 1): the Order jet stretched, with
-- a deep belly, a bomb `bay` with doors under it and a wing `pylon` rail
-- for heavy bombs. Model space, forward = -Z.

return {
	id = "ord_absolution",
	parts = {
		{ name = "base", shape = "box", size = { 1.6, 0.9, 8 }, at = { 0, 0.6, 0 }, color = "hull" },
		{ name = "nose", parent = "base", shape = "wedge", size = { 1.6, 0.9, 1.6 }, at = { 0, 0.6, -4.8 }, color = "hull" },
		{ name = "canopy", parent = "base", shape = "wedge", size = { 0.8, 0.45, 1.6 }, at = { 0, 1.25, -2.6 }, color = "glass" },
		{ name = "wingL", parent = "base", shape = "wedge", size = { 2.9, 0.2, 3.2 }, at = { -2.25, 0.45, 0.6 }, rot = { 0, -90, 0 }, color = "hull" },
		{ name = "wingR", parent = "base", shape = "wedge", size = { 2.9, 0.2, 3.2 }, at = { 2.25, 0.45, 0.6 }, rot = { 0, 90, 0 }, color = "hull" },
		{ name = "wingTeamL", parent = "base", shape = "box", size = { 1.2, 0.06, 1 }, at = { -2.45, 0.6, 1 }, color = "team" },
		{ name = "wingTeamR", parent = "base", shape = "box", size = { 1.2, 0.06, 1 }, at = { 2.45, 0.6, 1 }, color = "team" },
		{ name = "tailL", parent = "base", shape = "box", size = { 0.15, 1.3, 1.4 }, at = { -0.6, 1.55, 3.2 }, rot = { 0, 0, -15 }, color = "team" },
		{ name = "tailR", parent = "base", shape = "box", size = { 0.15, 1.3, 1.4 }, at = { 0.6, 1.55, 3.2 }, rot = { 0, 0, 15 }, color = "team" },
		{ name = "engineL", parent = "base", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 0.3 }, at = { -0.45, 0.6, 4.1 }, color = "glass" },
		{ name = "engineR", parent = "base", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 0.3 }, at = { 0.45, 0.6, 4.1 }, color = "glass" },
		{ name = "pylon", parent = "base", shape = "box", size = { 5.2, 0.25, 0.8 }, at = { 0, 0.2, 1 }, color = "dark" },
		{ name = "bay", parent = "base", shape = "box", size = { 1.2, 0.2, 2.6 }, at = { 0, 0.1, 0.2 }, color = "dark" },
		{ name = "bayLip", parent = "bay", shape = "box", size = { 1.4, 0.1, 0.2 }, at = { 0, 0.05, -1.1 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "bay", at = { 0, -0.1, 0.2 } },
	},
}
