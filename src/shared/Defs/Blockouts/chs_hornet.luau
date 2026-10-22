--!strict
-- Hornet (Chaos mobile IR SAM): heavy truck with an offset cab, a ram and a
-- stack; on the bed a ring and pedestal (turret) carrying a lopsided
-- launcher: a closed rack on the right, two bare missiles on a rail on the
-- left, a counterweight at the back. The def turns `launcher` (its
-- turretPiece); `turret` is the fixed pedestal (see docs/progress/models.md,
-- requests). Model space,
-- forward = -Z (docs/contracts/rig.md).

return {
	id = "chs_hornet",
	parts = {
		{ name = "base", shape = "box", size = { 4.6, 1.2, 6.8 }, at = { 0, 1.7, 0.3 }, color = "hull" },
		{ name = "ram", parent = "base", shape = "box", size = { 5.0, 0.8, 0.4 }, at = { 0, 1.3, -3.4 }, rot = { -20, 0, 0 }, color = "dark" },
		{ name = "cab", parent = "base", shape = "box", size = { 2.6, 1.2, 1.8 }, at = { -0.9, 2.9, -2.1 }, color = "hull" },
		{ name = "slit", parent = "base", shape = "box", size = { 2.0, 0.25, 0.1 }, at = { -0.9, 3.2, -3.02 }, color = "glass" },
		{ name = "stack", parent = "base", shape = "cylinder", axis = "y", size = { 0.5, 2.0, 0.5 }, at = { 1.4, 3.2, -2.4 }, color = "metal" },
		{ name = "wheel1L", parent = "base", shape = "cylinder", axis = "x", size = { 1.0, 1.8, 1.8 }, at = { -2.4, 0.9, -2.3 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "wheel1R", parent = "base", shape = "cylinder", axis = "x", size = { 1.0, 1.8, 1.8 }, at = { 2.4, 0.9, -2.3 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "wheel2L", parent = "base", shape = "cylinder", axis = "x", size = { 1.0, 1.8, 1.8 }, at = { -2.4, 0.9, 1.3 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "wheel2R", parent = "base", shape = "cylinder", axis = "x", size = { 1.0, 1.8, 1.8 }, at = { 2.4, 0.9, 1.3 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "wheel3L", parent = "base", shape = "cylinder", axis = "x", size = { 1.0, 1.8, 1.8 }, at = { -2.4, 0.9, 3.1 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "wheel3R", parent = "base", shape = "cylinder", axis = "x", size = { 1.0, 1.8, 1.8 }, at = { 2.4, 0.9, 3.1 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },

		{ name = "ring", parent = "base", shape = "cylinder", axis = "y", size = { 2.2, 0.3, 2.2 }, at = { 0.2, 2.45, 1.6 }, color = "dark" },

		{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 1.2, 1.2, 1.2 }, at = { 0.2, 2.9, 1.6 }, color = "dark" },

		{ name = "launcher", parent = "turret", shape = "box", size = { 0.8, 1.0, 1.0 }, at = { 0.2, 4.0, 1.6 }, color = "metal" },
		{ name = "rack", parent = "launcher", shape = "box", size = { 1.4, 1.2, 2.6 }, at = { 1.3, 4.1, 1.3 }, color = "team" },
		{ name = "seeker", parent = "launcher", shape = "box", size = { 0.5, 0.5, 0.1 }, at = { 1.3, 4.3, 0.0 }, color = "glass" },
		{ name = "rail", parent = "launcher", shape = "box", size = { 0.2, 1.2, 2.6 }, at = { -0.3, 4.0, 1.3 }, color = "dark" },
		{ name = "missile1", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.45, 0.45, 2.6 }, at = { -0.65, 4.3, 1.1 }, color = "metal" },
		{ name = "missile2", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.45, 0.45, 2.6 }, at = { -0.65, 3.75, 1.1 }, color = "metal" },
		{ name = "counterweight", parent = "launcher", shape = "box", size = { 1.6, 0.8, 0.6 }, at = { 0.2, 3.9, 2.9 }, color = "dark" },
	},
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { -0.65, 4.3, -0.2 } },
	},
}
