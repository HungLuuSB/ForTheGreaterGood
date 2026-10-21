--!strict
-- Lancer variant A (Order, Leopard 2A6 lines), for the style review: long low
-- hull, five road wheels under flat skirts, flat turret set back with an
-- arrowhead front, panoramic and gunner's sights, long gun. Light grey.
-- Model space, forward = -Z (docs/contracts/rig.md).

return {
	id = "ord_lancer",
	parts = {
		{ name = "base", shape = "box", size = { 5.8, 0.9, 7.4 }, at = { 0, 1.35, 0.3 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 5.8, 0.9, 1.0 }, at = { 0, 1.35, -3.9 }, color = "hull" },
		{ name = "deck", parent = "base", shape = "box", size = { 4.0, 0.1, 1.8 }, at = { 0, 1.85, 2.9 }, color = "dark" },
		{ name = "beltL", parent = "base", shape = "box", size = { 0.9, 0.2, 7.6 }, at = { -2.45, 0.1, 0 }, color = "track" },
		{ name = "beltR", parent = "base", shape = "box", size = { 0.9, 0.2, 7.6 }, at = { 2.45, 0.1, 0 }, color = "track" },
		{ name = "wheelL1", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.0, 1.0 }, at = { -2.45, 0.55, -2.9 }, color = "track" },
		{ name = "wheelL2", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.0, 1.0 }, at = { -2.45, 0.55, -1.45 }, color = "track" },
		{ name = "wheelL3", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.0, 1.0 }, at = { -2.45, 0.55, 0 }, color = "track" },
		{ name = "wheelL4", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.0, 1.0 }, at = { -2.45, 0.55, 1.45 }, color = "track" },
		{ name = "wheelL5", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.0, 1.0 }, at = { -2.45, 0.55, 2.9 }, color = "track" },
		{ name = "wheelR1", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.0, 1.0 }, at = { 2.45, 0.55, -2.9 }, color = "track" },
		{ name = "wheelR2", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.0, 1.0 }, at = { 2.45, 0.55, -1.45 }, color = "track" },
		{ name = "wheelR3", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.0, 1.0 }, at = { 2.45, 0.55, 0 }, color = "track" },
		{ name = "wheelR4", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.0, 1.0 }, at = { 2.45, 0.55, 1.45 }, color = "track" },
		{ name = "wheelR5", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.0, 1.0 }, at = { 2.45, 0.55, 2.9 }, color = "track" },
		{ name = "skirtL", parent = "base", shape = "box", size = { 0.2, 0.85, 7.8 }, at = { -3.0, 1.2, -0.1 }, color = "hull" },
		{ name = "skirtR", parent = "base", shape = "box", size = { 0.2, 0.85, 7.8 }, at = { 3.0, 1.2, -0.1 }, color = "hull" },
		{ name = "stripeL", parent = "base", shape = "box", size = { 0.06, 0.3, 2.0 }, at = { -3.12, 1.25, 2.0 }, color = "team" },
		{ name = "stripeR", parent = "base", shape = "box", size = { 0.06, 0.3, 2.0 }, at = { 3.12, 1.25, 2.0 }, color = "team" },

		{ name = "turret", parent = "base", shape = "box", size = { 3.6, 0.9, 3.4 }, at = { 0, 2.25, 1.0 }, color = "hull" },
		{ name = "cheekL", parent = "turret", shape = "wedge", size = { 1.9, 0.9, 1.6 }, at = { -0.85, 2.25, -1.2 }, rot = { 0, 25, 0 }, color = "hull" },
		{ name = "cheekR", parent = "turret", shape = "wedge", size = { 1.9, 0.9, 1.6 }, at = { 0.85, 2.25, -1.2 }, rot = { 0, -25, 0 }, color = "hull" },
		{ name = "bustle", parent = "turret", shape = "box", size = { 3.2, 0.7, 0.9 }, at = { 0, 2.2, 3.1 }, color = "dark" },
		{ name = "peri", parent = "turret", shape = "box", size = { 0.5, 0.6, 0.5 }, at = { -0.9, 2.95, 0.7 }, color = "dark" },
		{ name = "periGlass", parent = "turret", shape = "box", size = { 0.4, 0.2, 0.05 }, at = { -0.9, 3.05, 0.43 }, color = "glass" },
		{ name = "sight", parent = "turret", shape = "box", size = { 0.6, 0.35, 0.7 }, at = { 1.0, 2.85, -0.2 }, color = "dark" },
		{ name = "sightGlass", parent = "turret", shape = "box", size = { 0.45, 0.2, 0.05 }, at = { 1.0, 2.85, -0.57 }, color = "glass" },
		{ name = "roofPanel", parent = "turret", shape = "box", size = { 1.2, 0.06, 0.9 }, at = { 0.6, 2.73, 1.9 }, color = "team" },
		{ name = "panelL", parent = "turret", shape = "box", size = { 0.06, 0.35, 1.6 }, at = { -1.83, 2.3, 1.6 }, color = "team" },
		{ name = "panelR", parent = "turret", shape = "box", size = { 0.06, 0.35, 1.6 }, at = { 1.83, 2.3, 1.6 }, color = "team" },

		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.35, 0.35, 6.0 }, at = { 0, 2.3, -4.5 }, pivot = { 0, 2.3, -1.5 }, color = "metal" },
		{ name = "mantlet", parent = "barrel", shape = "box", size = { 1.0, 0.6, 0.4 }, at = { 0, 2.3, -1.9 }, color = "hull" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 2.3, -7.5 } },
	},
}
