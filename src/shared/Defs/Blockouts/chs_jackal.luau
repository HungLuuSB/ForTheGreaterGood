--!strict
-- Jackal (Chaos scout): open-frame buggy with a roll cage, an exposed engine
-- and one stack at the back, big rear wheels, and a shielded pintle gun off
-- to the right. Model space, forward = -Z (docs/contracts/rig.md).

return {
	id = "chs_jackal",
	parts = {
		{ name = "base", shape = "box", size = { 3.6, 0.8, 5.4 }, at = { 0, 1.3, 0.2 }, color = "hull" },
		{ name = "bumper", parent = "base", shape = "box", size = { 4.2, 0.6, 0.4 }, at = { 0, 1.0, -2.8 }, color = "dark" },
		{ name = "cabPlate", parent = "base", shape = "box", size = { 1.6, 0.8, 0.2 }, at = { -0.8, 2.1, -1.6 }, rot = { -20, 0, 0 }, color = "dark" },
		{ name = "slit", parent = "base", shape = "box", size = { 1.2, 0.15, 0.1 }, at = { -0.8, 2.25, -1.75 }, rot = { -20, 0, 0 }, color = "glass" },
		{ name = "cageL", parent = "base", shape = "box", size = { 0.2, 1.2, 0.2 }, at = { -1.5, 2.3, -0.6 }, color = "dark" },
		{ name = "cageR", parent = "base", shape = "box", size = { 0.2, 1.2, 0.2 }, at = { 1.5, 2.3, -0.6 }, color = "dark" },
		{ name = "cageTop", parent = "base", shape = "box", size = { 3.2, 0.2, 0.2 }, at = { 0, 2.9, -0.6 }, color = "dark" },
		{ name = "engine", parent = "base", shape = "box", size = { 2.0, 1.0, 1.6 }, at = { -0.3, 2.2, 2.0 }, color = "metal" },
		{ name = "stack", parent = "base", shape = "cylinder", axis = "y", size = { 0.35, 1.4, 0.35 }, at = { -1.4, 2.6, 2.6 }, color = "metal" },
		{ name = "wheelFL", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.3, 1.3 }, at = { -2.1, 0.65, -1.9 }, color = "track" },
		{ name = "wheelFR", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.3, 1.3 }, at = { 2.1, 0.65, -1.9 }, color = "track" },
		{ name = "wheelBL", parent = "base", shape = "cylinder", axis = "x", size = { 1.0, 1.8, 1.8 }, at = { -2.2, 0.9, 1.8 }, color = "track" },
		{ name = "wheelBR", parent = "base", shape = "cylinder", axis = "x", size = { 1.0, 1.8, 1.8 }, at = { 2.2, 0.9, 1.8 }, color = "track" },

		{ name = "turret", parent = "base", shape = "box", size = { 1.2, 0.6, 1.2 }, at = { 0.9, 2.0, 0.4 }, color = "team" },
		{ name = "shield", parent = "turret", shape = "box", size = { 1.3, 0.8, 0.15 }, at = { 0.9, 2.6, -0.3 }, color = "team" },
		{ name = "gun", parent = "turret", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 2.2 }, at = { 0.9, 2.5, -1.2 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "turret", at = { 0.9, 2.5, -2.3 } },
	},
}
