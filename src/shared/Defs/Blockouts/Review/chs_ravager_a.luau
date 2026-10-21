--!strict
-- Ravager variant A (Chaos, T-90M lines), for the style review: long low
-- hull with reactive-armor tiles on the glacis and the front of the skirts,
-- six road wheels, a low turret with a reactive-armor brow, a slat cage
-- round the back, a remote machine gun and a gunner's sight; long gun with
-- a fume extractor. Dark olive. Model space, forward = -Z
-- (docs/contracts/rig.md).

-- Glacis tiles lie on the 41° slope, 0.06 studs above it.
return {
	id = "chs_ravager",
	parts = {
		{ name = "base", shape = "box", size = { 5.8, 0.95, 7.4 }, at = { 0, 1.4, 0.3 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 5.8, 0.95, 1.1 }, at = { 0, 1.4, -3.95 }, color = "hull" },
		{ name = "tile1", parent = "base", shape = "box", size = { 1.3, 0.12, 1.3 }, at = { -2.1, 1.45, -4.0 }, rot = { -41, 0, 0 }, color = "dark" },
		{ name = "tile2", parent = "base", shape = "box", size = { 1.3, 0.12, 1.3 }, at = { -0.7, 1.45, -4.0 }, rot = { -41, 0, 0 }, color = "dark" },
		{ name = "tile3", parent = "base", shape = "box", size = { 1.3, 0.12, 1.3 }, at = { 0.7, 1.45, -4.0 }, rot = { -41, 0, 0 }, color = "dark" },
		{ name = "tile4", parent = "base", shape = "box", size = { 1.3, 0.12, 1.3 }, at = { 2.1, 1.45, -4.0 }, rot = { -41, 0, 0 }, color = "dark" },
		{ name = "deck", parent = "base", shape = "box", size = { 4.2, 0.1, 1.8 }, at = { 0, 1.92, 3.0 }, color = "dark" },
		{ name = "beltL", parent = "base", shape = "box", size = { 0.9, 0.2, 7.6 }, at = { -2.45, 0.1, 0 }, color = "track" },
		{ name = "beltR", parent = "base", shape = "box", size = { 0.9, 0.2, 7.6 }, at = { 2.45, 0.1, 0 }, color = "track" },
		{ name = "wheelL1", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.1, 1.1 }, at = { -2.45, 0.6, -3.0 }, color = "track" },
		{ name = "wheelL2", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.1, 1.1 }, at = { -2.45, 0.6, -1.8 }, color = "track" },
		{ name = "wheelL3", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.1, 1.1 }, at = { -2.45, 0.6, -0.6 }, color = "track" },
		{ name = "wheelL4", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.1, 1.1 }, at = { -2.45, 0.6, 0.6 }, color = "track" },
		{ name = "wheelL5", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.1, 1.1 }, at = { -2.45, 0.6, 1.8 }, color = "track" },
		{ name = "wheelL6", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.1, 1.1 }, at = { -2.45, 0.6, 3.0 }, color = "track" },
		{ name = "wheelR1", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.1, 1.1 }, at = { 2.45, 0.6, -3.0 }, color = "track" },
		{ name = "wheelR2", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.1, 1.1 }, at = { 2.45, 0.6, -1.8 }, color = "track" },
		{ name = "wheelR3", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.1, 1.1 }, at = { 2.45, 0.6, -0.6 }, color = "track" },
		{ name = "wheelR4", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.1, 1.1 }, at = { 2.45, 0.6, 0.6 }, color = "track" },
		{ name = "wheelR5", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.1, 1.1 }, at = { 2.45, 0.6, 1.8 }, color = "track" },
		{ name = "wheelR6", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.1, 1.1 }, at = { 2.45, 0.6, 3.0 }, color = "track" },
		{ name = "skirtL", parent = "base", shape = "box", size = { 0.25, 0.9, 7.6 }, at = { -3.0, 1.25, 0 }, color = "hull" },
		{ name = "skirtR", parent = "base", shape = "box", size = { 0.25, 0.9, 7.6 }, at = { 3.0, 1.25, 0 }, color = "hull" },
		{ name = "eraL1", parent = "base", shape = "box", size = { 0.15, 0.7, 1.1 }, at = { -3.18, 1.25, -3.0 }, color = "dark" },
		{ name = "eraL2", parent = "base", shape = "box", size = { 0.15, 0.7, 1.1 }, at = { -3.18, 1.25, -1.8 }, color = "dark" },
		{ name = "eraL3", parent = "base", shape = "box", size = { 0.15, 0.7, 1.1 }, at = { -3.18, 1.25, -0.6 }, color = "dark" },
		{ name = "eraR1", parent = "base", shape = "box", size = { 0.15, 0.7, 1.1 }, at = { 3.18, 1.25, -3.0 }, color = "dark" },
		{ name = "eraR2", parent = "base", shape = "box", size = { 0.15, 0.7, 1.1 }, at = { 3.18, 1.25, -1.8 }, color = "dark" },
		{ name = "eraR3", parent = "base", shape = "box", size = { 0.15, 0.7, 1.1 }, at = { 3.18, 1.25, -0.6 }, color = "dark" },
		{ name = "stripeL", parent = "base", shape = "box", size = { 0.06, 0.3, 2.0 }, at = { -3.14, 1.25, 2.2 }, color = "team" },
		{ name = "stripeR", parent = "base", shape = "box", size = { 0.06, 0.3, 2.0 }, at = { 3.14, 1.25, 2.2 }, color = "team" },

		{ name = "turret", parent = "base", shape = "box", size = { 3.6, 0.95, 3.2 }, at = { 0, 2.35, 0.9 }, color = "hull" },
		{ name = "browL", parent = "turret", shape = "box", size = { 1.5, 0.55, 1.3 }, at = { -1.05, 2.4, -1.2 }, rot = { -15, 0, 0 }, color = "dark" },
		{ name = "browR", parent = "turret", shape = "box", size = { 1.5, 0.55, 1.3 }, at = { 1.05, 2.4, -1.2 }, rot = { -15, 0, 0 }, color = "dark" },
		{ name = "cheekL", parent = "turret", shape = "box", size = { 0.25, 0.55, 1.2 }, at = { -1.9, 2.4, -0.1 }, color = "dark" },
		{ name = "cheekR", parent = "turret", shape = "box", size = { 0.25, 0.55, 1.2 }, at = { 1.9, 2.4, -0.1 }, color = "dark" },
		{ name = "roofPanel", parent = "turret", shape = "box", size = { 1.2, 0.06, 0.9 }, at = { -0.6, 2.86, 1.6 }, color = "team" },
		{ name = "cageTop", parent = "turret", shape = "box", size = { 3.8, 0.08, 0.08 }, at = { 0, 2.95, 3.0 }, color = "dark" },
		{ name = "cageLow", parent = "turret", shape = "box", size = { 3.8, 0.08, 0.08 }, at = { 0, 2.05, 3.0 }, color = "dark" },
		{ name = "cageL", parent = "turret", shape = "box", size = { 0.08, 0.9, 1.6 }, at = { -1.9, 2.5, 2.2 }, color = "dark" },
		{ name = "cageR", parent = "turret", shape = "box", size = { 0.08, 0.9, 1.6 }, at = { 1.9, 2.5, 2.2 }, color = "dark" },
		{ name = "slat1", parent = "turret", shape = "box", size = { 0.08, 0.85, 0.08 }, at = { -1.0, 2.5, 3.0 }, color = "dark" },
		{ name = "slat2", parent = "turret", shape = "box", size = { 0.08, 0.85, 0.08 }, at = { 0, 2.5, 3.0 }, color = "dark" },
		{ name = "slat3", parent = "turret", shape = "box", size = { 0.08, 0.85, 0.08 }, at = { 1.0, 2.5, 3.0 }, color = "dark" },
		{ name = "rws", parent = "turret", shape = "box", size = { 0.6, 0.45, 0.7 }, at = { 0.9, 3.05, 0.6 }, color = "dark" },
		{ name = "rwsGun", parent = "turret", shape = "cylinder", axis = "z", size = { 0.15, 0.15, 1.0 }, at = { 0.9, 3.1, -0.1 }, color = "metal" },
		{ name = "sight", parent = "turret", shape = "box", size = { 0.6, 0.45, 0.6 }, at = { -1.0, 3.05, -0.2 }, color = "dark" },
		{ name = "sightGlass", parent = "turret", shape = "box", size = { 0.45, 0.25, 0.05 }, at = { -1.0, 3.05, -0.52 }, color = "glass" },
		{ name = "panelL", parent = "turret", shape = "box", size = { 0.06, 0.35, 1.2 }, at = { -1.83, 2.4, 0.6 }, color = "team" },
		{ name = "panelR", parent = "turret", shape = "box", size = { 0.06, 0.35, 1.2 }, at = { 1.83, 2.4, 0.6 }, color = "team" },

		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.38, 0.38, 6.0 }, at = { 0, 2.4, -4.2 }, pivot = { 0, 2.4, -1.2 }, color = "metal" },
		{ name = "extractor", parent = "barrel", shape = "cylinder", axis = "z", size = { 0.52, 0.52, 0.7 }, at = { 0, 2.4, -3.6 }, color = "metal" },
		{ name = "mantlet", parent = "barrel", shape = "box", size = { 0.9, 0.6, 0.4 }, at = { 0, 2.4, -1.6 }, color = "hull" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 2.4, -7.2 } },
	},
}
