--!strict
-- Leech (Chaos ASW helicopter, T2, footprint 1): the Chaos airframe with
-- a sonar under the nose and two torpedoes on the `rack`; client-spun
-- `rotor`. Model space, forward = -Z.

return {
	id = "chs_leech",
	visualPieces = { "rotor" },
	parts = {
		{ name = "base", shape = "box", size = { 1.6, 1.5, 3.8 }, at = { 0, 1.2, -0.2 }, color = "hull" },
		{ name = "nose", parent = "base", shape = "ball", size = { 1.6, 1.3, 1.6 }, at = { 0, 1.1, -2.2 }, color = "glass" },
		{ name = "boom", parent = "base", shape = "box", size = { 0.35, 0.35, 4.2 }, at = { 0, 1.4, 3.8 }, color = "dark" },
		{ name = "boomBrace", parent = "base", shape = "box", size = { 0.15, 0.15, 3.8 }, at = { 0, 1, 3.6 }, rot = { -6, 0, 0 }, color = "dark" },
		{ name = "fin", parent = "base", shape = "box", size = { 0.15, 1.8, 1 }, at = { 0, 2.1, 5.7 }, color = "team" },
		{ name = "engine", parent = "base", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 1.8 }, at = { 0, 2.25, 0.6 }, color = "metal" },
		{ name = "exhaust", parent = "base", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 0.2 }, at = { 0, 2.25, 1.6 }, color = "glass" },
		{ name = "deckTeam", parent = "base", shape = "box", size = { 1.2, 0.06, 1.2 }, at = { 0, 1.98, -0.9 }, color = "team" },
		{ name = "wheelL", parent = "base", shape = "cylinder", axis = "x", size = { 0.25, 0.6, 0.6 }, at = { -0.8, 0.3, -0.8 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "wheelR", parent = "base", shape = "cylinder", axis = "x", size = { 0.25, 0.6, 0.6 }, at = { 0.8, 0.3, -0.8 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "mast", parent = "base", shape = "cylinder", axis = "y", size = { 0.35, 0.6, 0.35 }, at = { 0, 3.05, 0.2 }, color = "metal" },
		{ name = "rotor", parent = "base", shape = "box", size = { 8.6, 0.12, 0.45 }, at = { 0, 3.4, 0.2 }, color = "dark", anim = { motion = "spin", axis = { 0, 1, 0 } } },
		{ name = "blade2", parent = "rotor", shape = "box", size = { 0.45, 0.12, 8.6 }, at = { 0, 3.4, 0.2 }, color = "dark" },
		{ name = "tailRotor", parent = "base", shape = "cylinder", axis = "x", size = { 0.12, 1.6, 1.6 }, at = { 0.2, 2.1, 5.7 }, color = "dark", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "rack", parent = "base", shape = "box", size = { 2.6, 0.3, 1 }, at = { 0, 0.55, 0.2 }, color = "dark" },
		{ name = "torpL", parent = "rack", shape = "cylinder", axis = "z", size = { 0.45, 0.45, 2.2 }, at = { -1, 0.35, 0.2 }, color = "metal" },
		{ name = "torpR", parent = "rack", shape = "cylinder", axis = "z", size = { 0.45, 0.45, 2.2 }, at = { 1, 0.35, 0.2 }, color = "metal" },
		{ name = "sonar", parent = "base", shape = "cylinder", size = { 0.7, 0.6, 0.7 }, at = { 0, 0.2, -1.2 }, color = "glass", anim = { motion = "lower", axis = { 0, -1, 0 }, range = 8 } },
	},
	attachments = {
		{ name = "muzzle", parent = "rack", at = { 0, 0.35, -0.9 } },
	},
}
