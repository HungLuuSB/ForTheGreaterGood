--!strict
-- Buzzard (Chaos light air transport, T1, footprint 2; S-219): a skeletal
-- lifter, a cockpit pod with a bubble nose on an open lattice spine, an
-- exposed engine on top, tall thin legs and folded grapple talons under the
-- spine (the `cargo` attachment between them: where a carried unit hangs);
-- client-spun `rotor`. Model space, forward = -Z.

return {
	id = "chs_buzzard",
	visualPieces = { "rotor" },
	parts = {
		{ name = "base", shape = "box", size = { 2, 1.7, 3 }, at = { 0, 2.6, -2.6 }, color = "hull" },
		{ name = "nose", parent = "base", shape = "ball", size = { 1.9, 1.9, 1.6 }, at = { 0, 2.5, -4.4 }, color = "glass" },
		{ name = "roofTeam", parent = "base", shape = "box", size = { 1.5, 0.06, 1.8 }, at = { 0, 3.46, -2.4 }, color = "team" },
		{ name = "spineL", parent = "base", shape = "box", size = { 0.2, 1.3, 9.8 }, at = { -0.5, 2.7, 3.7 }, color = "dark" },
		{ name = "spineR", parent = "base", shape = "box", size = { 0.2, 1.3, 9.8 }, at = { 0.5, 2.7, 3.7 }, color = "dark" },
		{ name = "engine", parent = "base", shape = "cylinder", axis = "z", size = { 1.1, 1.1, 2.6 }, at = { 0, 3.75, 0.6 }, color = "metal" },
		{ name = "exhaust", parent = "base", shape = "cylinder", axis = "z", size = { 0.76, 0.76, 0.14 }, at = { 0, 3.75, 1.95 }, color = "glass" },
		{ name = "fin", parent = "base", shape = "box", size = { 0.16, 1.8, 1.5 }, at = { 0, 4.1, 9.4 }, color = "team" },
		{ name = "legL", parent = "base", shape = "box", size = { 0.14, 1.9, 0.14 }, at = { -1.2, 1.2, -0.2 }, rot = { 0, 0, -32 }, color = "metal" },
		{ name = "legR", parent = "base", shape = "box", size = { 0.14, 1.9, 0.14 }, at = { 1.2, 1.2, -0.2 }, rot = { 0, 0, 32 }, color = "metal" },
		{ name = "footL", parent = "base", shape = "cylinder", axis = "x", size = { 0.22, 0.64, 0.64 }, at = { -1.85, 0.32, 0.2 }, color = "track" },
		{ name = "footR", parent = "base", shape = "cylinder", axis = "x", size = { 0.22, 0.64, 0.64 }, at = { 1.85, 0.32, 0.2 }, color = "track" },
		{ name = "talonBeam", parent = "base", shape = "box", size = { 3, 0.22, 0.22 }, at = { 0, 1.6, 0.4 }, color = "dark" },
		{ name = "talonL", parent = "base", shape = "box", size = { 0.16, 1.1, 0.7 }, at = { -1.25, 1, 0.4 }, color = "metal" },
		{ name = "talonR", parent = "base", shape = "box", size = { 0.16, 1.1, 0.7 }, at = { 1.25, 1, 0.4 }, color = "metal" },
		{ name = "mast", parent = "base", shape = "cylinder", axis = "y", size = { 0.4, 0.8, 0.4 }, at = { 0, 4.2, -0.4 }, color = "metal" },
		{ name = "rotor", parent = "base", shape = "box", size = { 14, 0.12, 0.55 }, at = { 0, 4.6, -0.4 }, color = "dark", anim = { motion = "spin", axis = { 0, 1, 0 } } },
		{ name = "tailRotor", parent = "base", shape = "cylinder", axis = "x", size = { 0.12, 2.1, 2.1 }, at = { 0.28, 3.9, 9.6 }, color = "dark", anim = { motion = "spin", axis = { 1, 0, 0 } } },
	},
	attachments = {
		{ name = "cargo", parent = "base", at = { 0, 0.5, 0.4 } },
	},
}
