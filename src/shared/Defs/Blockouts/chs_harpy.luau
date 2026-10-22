--!strict
-- Harpy (Chaos fighter, T1, footprint 1): a round fuselage on a big delta
-- wing with canards, one tall tail in team color, exposed engine pods with
-- orange glow; four cheap missiles on the belly `pylon`.
-- Model space, forward = -Z.

return {
	id = "chs_harpy",
	parts = {
		{ name = "base", shape = "cylinder", axis = "z", size = { 1.3, 1.3, 7 }, at = { 0, 0.7, 0 }, color = "hull" },
		{ name = "nose", parent = "base", shape = "wedge", size = { 1.2, 1, 1.8 }, at = { 0, 0.65, -4.4 }, color = "hull" },
		{ name = "canopy", parent = "base", shape = "ball", size = { 0.8, 0.6, 1.4 }, at = { 0, 1.35, -2.2 }, color = "glass" },
		{ name = "delta", parent = "base", shape = "wedge", size = { 6.8, 0.2, 4.4 }, at = { 0, 0.5, 1 }, color = "hull" },
		{ name = "deltaTeam", parent = "base", shape = "box", size = { 3.4, 0.06, 1 }, at = { 0, 0.62, 2.4 }, color = "team" },
		{ name = "canardL", parent = "base", shape = "box", size = { 1.6, 0.12, 0.7 }, at = { -1.1, 0.9, -1.9 }, color = "dark" },
		{ name = "canardR", parent = "base", shape = "box", size = { 1.6, 0.12, 0.7 }, at = { 1.1, 0.9, -1.9 }, color = "dark" },
		{ name = "tail", parent = "base", shape = "box", size = { 0.18, 1.9, 1.8 }, at = { 0, 2, 2.6 }, color = "team" },
		{ name = "podL", parent = "base", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 2.4 }, at = { -1, 0.45, 2.5 }, color = "metal" },
		{ name = "podR", parent = "base", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 2.4 }, at = { 1, 0.45, 2.5 }, color = "metal" },
		{ name = "glowL", parent = "base", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 0.2 }, at = { -1, 0.45, 3.75 }, color = "glass" },
		{ name = "glowR", parent = "base", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 0.2 }, at = { 1, 0.45, 3.75 }, color = "glass" },
		{ name = "pylon", parent = "base", shape = "box", size = { 1, 0.35, 2.4 }, at = { 0, -0.05, 0 }, color = "dark" },
		{ name = "missile0", parent = "pylon", shape = "cylinder", axis = "z", size = { 0.25, 0.25, 1.6 }, at = { -0.6, -0.3, -0.2 }, color = "metal" },
		{ name = "missile1", parent = "pylon", shape = "cylinder", axis = "z", size = { 0.25, 0.25, 1.6 }, at = { 0.6, -0.3, -0.2 }, color = "metal" },
		{ name = "missile2", parent = "pylon", shape = "cylinder", axis = "z", size = { 0.25, 0.25, 1.6 }, at = { -1.4, -0.3, -0.2 }, color = "metal" },
		{ name = "missile3", parent = "pylon", shape = "cylinder", axis = "z", size = { 0.25, 0.25, 1.6 }, at = { 1.4, -0.3, -0.2 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "pylon", at = { 0, -0.3, -1.2 } },
	},
}
