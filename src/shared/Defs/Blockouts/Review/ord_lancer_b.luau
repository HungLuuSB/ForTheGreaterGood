--!strict
-- Lancer variant B (Order, Abrams lines), for the style review: long low
-- hull with a steep glacis, six road wheels under skirts, a wide flat slab
-- turret with a long bustle, commander's sight, gunner's sight and a small
-- remote gun, long gun. Sand. Model space, forward = -Z
-- (docs/contracts/rig.md).

return {
	id = "ord_lancer",
	parts = {
		{ name = "base", shape = "box", size = { 5.8, 0.9, 7.6 }, at = { 0, 1.35, 0.2 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 5.8, 0.9, 1.2 }, at = { 0, 1.35, -4.0 }, color = "hull" },
		{ name = "deck", parent = "base", shape = "box", size = { 4.2, 0.1, 1.6 }, at = { 0, 1.85, 3.1 }, color = "dark" },
		{ name = "beltL", parent = "base", shape = "box", size = { 0.9, 0.2, 7.8 }, at = { -2.45, 0.1, 0 }, color = "track" },
		{ name = "beltR", parent = "base", shape = "box", size = { 0.9, 0.2, 7.8 }, at = { 2.45, 0.1, 0 }, color = "track" },
		{ name = "wheelL1", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 0.95, 0.95 }, at = { -2.45, 0.55, -3.0 }, color = "track" },
		{ name = "wheelL2", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 0.95, 0.95 }, at = { -2.45, 0.55, -1.8 }, color = "track" },
		{ name = "wheelL3", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 0.95, 0.95 }, at = { -2.45, 0.55, -0.6 }, color = "track" },
		{ name = "wheelL4", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 0.95, 0.95 }, at = { -2.45, 0.55, 0.6 }, color = "track" },
		{ name = "wheelL5", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 0.95, 0.95 }, at = { -2.45, 0.55, 1.8 }, color = "track" },
		{ name = "wheelL6", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 0.95, 0.95 }, at = { -2.45, 0.55, 3.0 }, color = "track" },
		{ name = "wheelR1", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 0.95, 0.95 }, at = { 2.45, 0.55, -3.0 }, color = "track" },
		{ name = "wheelR2", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 0.95, 0.95 }, at = { 2.45, 0.55, -1.8 }, color = "track" },
		{ name = "wheelR3", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 0.95, 0.95 }, at = { 2.45, 0.55, -0.6 }, color = "track" },
		{ name = "wheelR4", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 0.95, 0.95 }, at = { 2.45, 0.55, 0.6 }, color = "track" },
		{ name = "wheelR5", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 0.95, 0.95 }, at = { 2.45, 0.55, 1.8 }, color = "track" },
		{ name = "wheelR6", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 0.95, 0.95 }, at = { 2.45, 0.55, 3.0 }, color = "track" },
		{ name = "skirtL", parent = "base", shape = "box", size = { 0.2, 0.85, 8.0 }, at = { -3.0, 1.2, -0.1 }, color = "hull" },
		{ name = "skirtR", parent = "base", shape = "box", size = { 0.2, 0.85, 8.0 }, at = { 3.0, 1.2, -0.1 }, color = "hull" },
		{ name = "stripeL", parent = "base", shape = "box", size = { 0.06, 0.3, 1.6 }, at = { -3.12, 1.25, -2.6 }, color = "team" },
		{ name = "stripeR", parent = "base", shape = "box", size = { 0.06, 0.3, 1.6 }, at = { 3.12, 1.25, -2.6 }, color = "team" },

		{ name = "turret", parent = "base", shape = "box", size = { 4.0, 0.8, 3.2 }, at = { 0, 2.2, 1.2 }, color = "hull" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 4.0, 0.8, 1.0 }, at = { 0, 2.2, -0.9 }, color = "hull" },
		{ name = "bustle", parent = "turret", shape = "box", size = { 3.4, 0.7, 1.4 }, at = { 0, 2.15, 3.5 }, color = "hull" },
		{ name = "rack", parent = "turret", shape = "box", size = { 3.4, 0.08, 1.4 }, at = { 0, 2.54, 3.5 }, color = "dark" },
		{ name = "roofPanel", parent = "turret", shape = "box", size = { 1.2, 0.06, 0.9 }, at = { -0.9, 2.63, 1.9 }, color = "team" },
		{ name = "citv", parent = "turret", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { -1.2, 2.9, 0.4 }, color = "dark" },
		{ name = "citvGlass", parent = "turret", shape = "box", size = { 0.45, 0.25, 0.05 }, at = { -1.2, 2.95, 0.08 }, color = "glass" },
		{ name = "sight", parent = "turret", shape = "box", size = { 0.8, 0.4, 0.6 }, at = { 1.2, 2.8, -0.3 }, color = "dark" },
		{ name = "sightGlass", parent = "turret", shape = "box", size = { 0.6, 0.25, 0.05 }, at = { 1.2, 2.8, -0.62 }, color = "glass" },
		{ name = "rws", parent = "turret", shape = "box", size = { 0.5, 0.4, 0.6 }, at = { 1.2, 2.8, 1.6 }, color = "dark" },
		{ name = "rwsGun", parent = "turret", shape = "cylinder", axis = "z", size = { 0.12, 0.12, 0.9 }, at = { 1.2, 2.85, 0.9 }, color = "metal" },
		{ name = "panelL", parent = "turret", shape = "box", size = { 0.06, 0.3, 1.4 }, at = { -2.03, 2.2, 1.8 }, color = "team" },
		{ name = "panelR", parent = "turret", shape = "box", size = { 0.06, 0.3, 1.4 }, at = { 2.03, 2.2, 1.8 }, color = "team" },

		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 6.2 }, at = { 0, 2.25, -4.5 }, pivot = { 0, 2.25, -1.4 }, color = "metal" },
		{ name = "mantlet", parent = "barrel", shape = "box", size = { 1.2, 0.5, 0.4 }, at = { 0, 2.25, -1.5 }, color = "hull" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 2.25, -7.6 } },
	},
}
