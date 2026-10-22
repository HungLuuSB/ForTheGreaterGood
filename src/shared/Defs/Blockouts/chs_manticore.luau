--!strict
-- Manticore (Chaos air superiority fighter, T2, footprint 1): a bigger
-- Harpy with a chin sensor `turret` (its heavy missiles turn it) and the
-- belly `pylon`; flare dispensers on the pods.
-- Model space, forward = -Z.

return {
	id = "chs_manticore",
	parts = {
		{ name = "base", shape = "cylinder", axis = "z", size = { 1.3, 1.3, 7.8 }, at = { 0, 0.7, 0 }, color = "hull" },
		{ name = "nose", parent = "base", shape = "wedge", size = { 1.2, 1, 1.8 }, at = { 0, 0.65, -4.8 }, color = "hull" },
		{ name = "canopy", parent = "base", shape = "ball", size = { 0.8, 0.6, 1.4 }, at = { 0, 1.35, -2.6 }, color = "glass" },
		{ name = "delta", parent = "base", shape = "wedge", size = { 7.4, 0.2, 4.4 }, at = { 0, 0.5, 1 }, color = "hull" },
		{ name = "deltaTeam", parent = "base", shape = "box", size = { 3.7, 0.06, 1 }, at = { 0, 0.62, 2.4 }, color = "team" },
		{ name = "canardL", parent = "base", shape = "box", size = { 1.6, 0.12, 0.7 }, at = { -1.1, 0.9, -2.3 }, color = "dark" },
		{ name = "canardR", parent = "base", shape = "box", size = { 1.6, 0.12, 0.7 }, at = { 1.1, 0.9, -2.3 }, color = "dark" },
		{ name = "tail", parent = "base", shape = "box", size = { 0.18, 1.9, 1.8 }, at = { 0, 2, 3 }, color = "team" },
		{ name = "podL", parent = "base", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 2.4 }, at = { -1, 0.45, 2.9 }, color = "metal" },
		{ name = "podR", parent = "base", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 2.4 }, at = { 1, 0.45, 2.9 }, color = "metal" },
		{ name = "glowL", parent = "base", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 0.2 }, at = { -1, 0.45, 4.15 }, color = "glass" },
		{ name = "glowR", parent = "base", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 0.2 }, at = { 1, 0.45, 4.15 }, color = "glass" },
		{ name = "pylon", parent = "base", shape = "box", size = { 1, 0.35, 2.4 }, at = { 0, -0.05, 0 }, color = "dark" },
		{ name = "missile0", parent = "pylon", shape = "cylinder", axis = "z", size = { 0.25, 0.25, 1.6 }, at = { -0.6, -0.3, -0.2 }, color = "metal" },
		{ name = "missile1", parent = "pylon", shape = "cylinder", axis = "z", size = { 0.25, 0.25, 1.6 }, at = { 0.6, -0.3, -0.2 }, color = "metal" },
		{ name = "missile2", parent = "pylon", shape = "cylinder", axis = "z", size = { 0.25, 0.25, 1.6 }, at = { -1.4, -0.3, -0.2 }, color = "metal" },
		{ name = "missile3", parent = "pylon", shape = "cylinder", axis = "z", size = { 0.25, 0.25, 1.6 }, at = { 1.4, -0.3, -0.2 }, color = "metal" },
		{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 0.8, 0.5, 0.8 }, at = { 0, 0, -2.9 }, color = "dark" },
		{ name = "sensor", parent = "turret", shape = "ball", size = { 0.4, 0.4, 0.4 }, at = { 0, -0.15, -3.2 }, color = "glass" },
		{ name = "flareL", parent = "base", shape = "box", size = { 0.3, 0.3, 0.8 }, at = { -1.45, 0.75, 2.4 }, color = "dark" },
		{ name = "flareR", parent = "base", shape = "box", size = { 0.3, 0.3, 0.8 }, at = { 1.45, 0.75, 2.4 }, color = "dark" },
	},
	attachments = {
		{ name = "muzzle", parent = "turret", at = { 0, -0.1, -3.5 } },
	},
}
