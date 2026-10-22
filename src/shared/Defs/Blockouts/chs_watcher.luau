--!strict
-- Watcher (Chaos mobile radar): heavy truck with a ram and a slit cab; an
-- exposed generator and stack on the right, a braced mast on the left
-- carrying a round dish tilted back with a glowing feed horn. Model space,
-- forward = -Z (docs/contracts/rig.md).

-- The feed sits along the dish normal (0, sin 25°, -cos 25°).
return {
	id = "chs_watcher",
	parts = {
		{ name = "base", shape = "box", size = { 4.6, 1.3, 7.2 }, at = { 0, 1.75, 0.2 }, color = "hull" },
		{ name = "ram", parent = "base", shape = "box", size = { 5.0, 0.8, 0.4 }, at = { 0, 1.3, -3.6 }, rot = { -20, 0, 0 }, color = "dark" },
		{ name = "cab", parent = "base", shape = "box", size = { 4.0, 1.2, 1.8 }, at = { 0, 3.0, -2.4 }, color = "hull" },
		{ name = "slit", parent = "base", shape = "box", size = { 3.0, 0.25, 0.1 }, at = { 0, 3.3, -3.32 }, color = "glass" },
		{ name = "generator", parent = "base", shape = "box", size = { 1.4, 1.2, 2.0 }, at = { 1.5, 3.0, 1.9 }, color = "metal" },
		{ name = "stack", parent = "base", shape = "cylinder", axis = "y", size = { 0.45, 1.6, 0.45 }, at = { 1.9, 4.1, 2.7 }, color = "metal" },
		{ name = "mast", parent = "base", shape = "box", size = { 0.6, 2.0, 0.6 }, at = { -1.0, 3.4, 1.4 }, color = "dark" },
		{ name = "brace", parent = "base", shape = "box", size = { 0.2, 1.8, 0.2 }, at = { -1.6, 3.2, 2.1 }, rot = { 20, 0, -15 }, color = "dark" },
		{ name = "wheel1L", parent = "base", shape = "cylinder", axis = "x", size = { 1.0, 1.8, 1.8 }, at = { -2.45, 0.9, -2.3 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "wheel1R", parent = "base", shape = "cylinder", axis = "x", size = { 1.0, 1.8, 1.8 }, at = { 2.45, 0.9, -2.3 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "wheel2L", parent = "base", shape = "cylinder", axis = "x", size = { 1.0, 1.8, 1.8 }, at = { -2.45, 0.9, 2.3 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "wheel2R", parent = "base", shape = "cylinder", axis = "x", size = { 1.0, 1.8, 1.8 }, at = { 2.45, 0.9, 2.3 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },

		{ name = "dish", parent = "base", shape = "cylinder", axis = "z", size = { 3.6, 3.6, 0.4 }, at = { -1.0, 5.6, 1.4 }, rot = { 25, 0, 0 }, pivot = { -1.0, 4.4, 1.4 }, color = "team", anim = { motion = "turn", axis = { 0, 1, 0 } } },
		{ name = "feed", parent = "dish", shape = "cylinder", axis = "z", size = { 0.2, 0.2, 1.6 }, at = { -1.0, 5.98, 0.58 }, rot = { 25, 0, 0 }, color = "metal" },
		{ name = "horn", parent = "dish", shape = "ball", size = { 0.45, 0.45, 0.45 }, at = { -1.0, 6.32, -0.14 }, color = "glass" },
	},
}
