--!strict
-- Lancer (Order light tank): low, clean, sloped; long precise cannon.
-- Model space, forward = -Z (docs/contracts/rig.md).

return {
	id = "ord_lancer",
	parts = {
		{ name = "base", shape = "box", size = { 5.2, 1.2, 7.0 }, at = { 0, 1.5, 0.2 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 5.2, 1.2, 1.4 }, at = { 0, 1.5, -4.0 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.1, 1.3, 8.0 }, at = { -2.75, 0.65, -0.2 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.1, 1.3, 8.0 }, at = { 2.75, 0.65, -0.2 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "fenderL", parent = "base", shape = "box", size = { 1.3, 0.2, 7.6 }, at = { -2.75, 1.4, -0.2 }, color = "dark" },
		{ name = "fenderR", parent = "base", shape = "box", size = { 1.3, 0.2, 7.6 }, at = { 2.75, 1.4, -0.2 }, color = "dark" },
		{ name = "deck", parent = "base", shape = "box", size = { 4.2, 0.3, 1.8 }, at = { 0, 2.25, 2.7 }, color = "dark" },

		{ name = "turret", parent = "base", shape = "box", size = { 3.2, 1.0, 3.4 }, at = { 0, 2.6, 0.3 }, color = "team" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 3.2, 1.0, 1.0 }, at = { 0, 2.6, -1.9 }, color = "team" },
		{ name = "cupola", parent = "turret", shape = "cylinder", axis = "y", size = { 0.9, 0.4, 0.9 }, at = { -0.8, 3.3, 0.9 }, color = "glass" },
		{ name = "antenna", parent = "turret", shape = "box", size = { 0.12, 1.4, 0.12 }, at = { 1.2, 3.8, 1.6 }, color = "dark" },

		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.4, 0.4, 5.0 }, at = { 0, 2.6, -4.6 }, pivot = { 0, 2.6, -2.2 }, color = "metal" },
		{ name = "mantlet", parent = "barrel", shape = "box", size = { 1.0, 0.7, 0.5 }, at = { 0, 2.6, -2.5 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 2.6, -7.1 } },
	},
}
