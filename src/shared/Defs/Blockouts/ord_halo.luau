--!strict
-- Halo (Order mobile IR SAM): six-wheeled carrier with a glass cab and a
-- pedestal (turret) carrying twin missile pods either side of a sensor head
-- (launcher). The def turns `launcher` (its turretPiece), so the launcher's
-- pivot sits on the pedestal's axis; `turret` is the fixed pedestal (see
-- docs/progress/models.md, requests). Model space, forward = -Z
-- (docs/contracts/rig.md).

return {
	id = "ord_halo",
	parts = {
		{ name = "base", shape = "box", size = { 4.4, 1.2, 6.4 }, at = { 0, 1.6, 0.4 }, color = "hull" },
		{ name = "nose", parent = "base", shape = "wedge", size = { 4.4, 1.2, 1.4 }, at = { 0, 1.6, -3.5 }, color = "hull" },
		{ name = "cab", parent = "base", shape = "box", size = { 3.6, 0.8, 1.4 }, at = { 0, 2.6, -1.6 }, color = "hull" },
		{ name = "windshield", parent = "base", shape = "wedge", size = { 3.6, 0.8, 0.7 }, at = { 0, 2.6, -2.65 }, color = "glass" },
		{ name = "wheel1L", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.5, 1.5 }, at = { -2.4, 0.75, -2.4 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "wheel1R", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.5, 1.5 }, at = { 2.4, 0.75, -2.4 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "wheel2L", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.5, 1.5 }, at = { -2.4, 0.75, 0.2 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "wheel2R", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.5, 1.5 }, at = { 2.4, 0.75, 0.2 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "wheel3L", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.5, 1.5 }, at = { -2.4, 0.75, 2.6 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "wheel3R", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.5, 1.5 }, at = { 2.4, 0.75, 2.6 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },

		{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 1.4, 1.2, 1.4 }, at = { 0, 2.8, 1.6 }, color = "dark" },

		{ name = "launcher", parent = "turret", shape = "box", size = { 1.3, 1.2, 1.4 }, at = { 0, 4.0, 1.6 }, color = "team" },
		{ name = "sensor", parent = "launcher", shape = "box", size = { 0.8, 0.5, 0.1 }, at = { 0, 4.15, 0.86 }, color = "glass" },
		{ name = "podL", parent = "launcher", shape = "box", size = { 1.1, 1.2, 3.0 }, at = { -1.25, 4.0, 1.3 }, color = "team" },
		{ name = "podR", parent = "launcher", shape = "box", size = { 1.1, 1.2, 3.0 }, at = { 1.25, 4.0, 1.3 }, color = "team" },
		{ name = "capsL", parent = "launcher", shape = "box", size = { 0.9, 1.0, 0.1 }, at = { -1.25, 4.0, -0.25 }, color = "dark" },
		{ name = "capsR", parent = "launcher", shape = "box", size = { 0.9, 1.0, 0.1 }, at = { 1.25, 4.0, -0.25 }, color = "dark" },
	},
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { -1.25, 4.0, -0.35 } },
	},
}
