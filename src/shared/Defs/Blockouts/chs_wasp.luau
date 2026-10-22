--!strict
-- Wasp (Chaos attack helicopter, T1, footprint 1): a glass bubble nose, an
-- exposed engine with orange exhaust over the cabin, a lattice-braced boom
-- and team fin, wheels; rocket pods on the `pylon` stubs; client-spun
-- `rotor`. Model space, forward = -Z.

return {
	id = "chs_wasp",
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
		{ name = "wheelL", parent = "base", shape = "cylinder", axis = "x", size = { 0.25, 0.6, 0.6 }, at = { -0.8, 0.3, -0.8 }, color = "track" },
		{ name = "wheelR", parent = "base", shape = "cylinder", axis = "x", size = { 0.25, 0.6, 0.6 }, at = { 0.8, 0.3, -0.8 }, color = "track" },
		{ name = "mast", parent = "base", shape = "cylinder", axis = "y", size = { 0.35, 0.6, 0.35 }, at = { 0, 3.05, 0.2 }, color = "metal" },
		{ name = "rotor", parent = "base", shape = "box", size = { 8.6, 0.12, 0.45 }, at = { 0, 3.4, 0.2 }, color = "dark" },
		{ name = "blade2", parent = "rotor", shape = "box", size = { 0.45, 0.12, 8.6 }, at = { 0, 3.4, 0.2 }, color = "dark" },
		{ name = "tailRotor", parent = "base", shape = "cylinder", axis = "x", size = { 0.12, 1.6, 1.6 }, at = { 0.2, 2.1, 5.7 }, color = "dark" },
		{ name = "stubs", parent = "base", shape = "box", size = { 3.4, 0.2, 0.8 }, at = { 0, 0.9, -0.4 }, color = "dark" },
		{ name = "pylon", parent = "base", shape = "box", size = { 3, 0.5, 0.9 }, at = { 0, 0.6, -0.4 }, color = "dark" },
		{ name = "podL", parent = "pylon", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 1.6 }, at = { -1.3, 0.55, -0.5 }, color = "metal" },
		{ name = "podR", parent = "pylon", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 1.6 }, at = { 1.3, 0.55, -0.5 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "pylon", at = { 0, 0.55, -1.4 } },
	},
}
