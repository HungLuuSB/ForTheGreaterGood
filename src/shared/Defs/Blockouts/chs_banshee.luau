--!strict
-- Banshee (Chaos EW jammer jet, T2, footprint 1): the Chaos delta with a
-- flat jammer `dish` box on the spine (a panel, never a dish), its top
-- glowing. Unarmed. Model space, forward = -Z.

return {
	id = "chs_banshee",
	parts = {
		{ name = "base", shape = "cylinder", axis = "z", size = { 1.3, 1.3, 7.4 }, at = { 0, 0.7, 0 }, color = "hull" },
		{ name = "nose", parent = "base", shape = "wedge", size = { 1.2, 1, 1.8 }, at = { 0, 0.65, -4.6 }, color = "hull" },
		{ name = "canopy", parent = "base", shape = "ball", size = { 0.8, 0.6, 1.4 }, at = { 0, 1.35, -2.4 }, color = "glass" },
		{ name = "delta", parent = "base", shape = "wedge", size = { 7, 0.2, 4.4 }, at = { 0, 0.5, 1 }, color = "hull" },
		{ name = "deltaTeam", parent = "base", shape = "box", size = { 3.5, 0.06, 1 }, at = { 0, 0.62, 2.4 }, color = "team" },
		{ name = "canardL", parent = "base", shape = "box", size = { 1.6, 0.12, 0.7 }, at = { -1.1, 0.9, -2.1 }, color = "dark" },
		{ name = "canardR", parent = "base", shape = "box", size = { 1.6, 0.12, 0.7 }, at = { 1.1, 0.9, -2.1 }, color = "dark" },
		{ name = "tail", parent = "base", shape = "box", size = { 0.18, 1.9, 1.8 }, at = { 0, 2, 2.8 }, color = "team" },
		{ name = "podL", parent = "base", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 2.4 }, at = { -1, 0.45, 2.7 }, color = "metal" },
		{ name = "podR", parent = "base", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 2.4 }, at = { 1, 0.45, 2.7 }, color = "metal" },
		{ name = "glowL", parent = "base", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 0.2 }, at = { -1, 0.45, 3.95 }, color = "glass" },
		{ name = "glowR", parent = "base", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 0.2 }, at = { 1, 0.45, 3.95 }, color = "glass" },
		{ name = "dish", parent = "base", shape = "box", size = { 2.6, 0.5, 2.2 }, at = { 0, 1.7, 0.6 }, color = "dark", anim = { motion = "turn", axis = { 0, 1, 0 } } },
		{ name = "dishGlow", parent = "dish", shape = "box", size = { 2.2, 0.06, 1.8 }, at = { 0, 1.97, 0.6 }, color = "glass" },
		{ name = "podGlowL", parent = "base", shape = "box", size = { 0.12, 0.3, 1.2 }, at = { -1.4, 0.45, 2.4 }, color = "glass" },
		{ name = "podGlowR", parent = "base", shape = "box", size = { 0.12, 0.3, 1.2 }, at = { 1.4, 0.45, 2.4 }, color = "glass" },
	},
}
