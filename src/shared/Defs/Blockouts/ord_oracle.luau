--!strict
-- Oracle (Order mobile radar): six-wheeled carrier with a glass cab and an
-- equipment shelter; a mast at the back carries a wide flat array (dish),
-- tilted back, that turns about the mast. Model space, forward = -Z
-- (docs/contracts/rig.md).

-- The array face sits 0.2 studs in front of the panel along its normal,
-- (0, sin 20°, -cos 20°).
return {
	id = "ord_oracle",
	parts = {
		{ name = "base", shape = "box", size = { 4.2, 1.2, 7.0 }, at = { 0, 1.6, 0.2 }, color = "hull" },
		{ name = "nose", parent = "base", shape = "wedge", size = { 4.2, 1.2, 1.2 }, at = { 0, 1.6, -3.9 }, color = "hull" },
		{ name = "cab", parent = "base", shape = "box", size = { 3.6, 1.0, 1.4 }, at = { 0, 2.7, -2.1 }, color = "hull" },
		{ name = "windshield", parent = "base", shape = "wedge", size = { 3.6, 1.0, 0.7 }, at = { 0, 2.7, -3.15 }, color = "glass" },
		{ name = "shelter", parent = "base", shape = "box", size = { 3.4, 1.2, 2.8 }, at = { 0, 2.8, 1.6 }, color = "dark" },
		{ name = "mast", parent = "base", shape = "cylinder", axis = "y", size = { 0.5, 1.0, 0.5 }, at = { 0, 3.9, 1.6 }, color = "metal" },
		{ name = "wheel1L", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.5, 1.5 }, at = { -2.3, 0.75, -2.6 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "wheel1R", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.5, 1.5 }, at = { 2.3, 0.75, -2.6 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "wheel2L", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.5, 1.5 }, at = { -2.3, 0.75, 0.2 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "wheel2R", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.5, 1.5 }, at = { 2.3, 0.75, 0.2 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "wheel3L", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.5, 1.5 }, at = { -2.3, 0.75, 2.8 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "wheel3R", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.5, 1.5 }, at = { 2.3, 0.75, 2.8 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },

		{ name = "dish", parent = "base", shape = "box", size = { 4.6, 2.2, 0.3 }, at = { 0, 5.4, 1.6 }, rot = { 20, 0, 0 }, pivot = { 0, 4.4, 1.6 }, color = "team", anim = { motion = "turn", axis = { 0, 1, 0 } } },
		{ name = "array", parent = "dish", shape = "box", size = { 4.2, 1.9, 0.1 }, at = { 0, 5.47, 1.41 }, rot = { 20, 0, 0 }, color = "glass" },
	},
}
