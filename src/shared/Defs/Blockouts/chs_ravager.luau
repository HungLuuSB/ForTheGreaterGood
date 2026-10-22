--!strict
-- Ravager (Chaos light tank): tall heavy blocks, ram plate, short thick gun.
-- Model space, forward = -Z (docs/contracts/rig.md).

return {
	id = "chs_ravager",
	parts = {
		{ name = "base", shape = "box", size = { 5.6, 1.5, 7.0 }, at = { 0, 1.65, 0.2 }, color = "hull" },
		{ name = "ram", parent = "base", shape = "box", size = { 6.0, 1.1, 0.5 }, at = { 0, 1.0, -3.6 }, rot = { -25, 0, 0 }, color = "dark" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.3, 1.5, 7.6 }, at = { -2.95, 0.75, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.3, 1.5, 7.6 }, at = { 2.95, 0.75, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "skirtL", parent = "base", shape = "box", size = { 0.3, 1.1, 6.6 }, at = { -3.75, 1.5, 0.1 }, color = "dark" },
		{ name = "skirtR", parent = "base", shape = "box", size = { 0.3, 1.1, 6.6 }, at = { 3.75, 1.5, 0.1 }, color = "dark" },
		{ name = "stackL", parent = "base", shape = "cylinder", axis = "y", size = { 0.5, 1.4, 0.5 }, at = { -1.9, 3.1, 3.1 }, color = "metal" },
		{ name = "stackR", parent = "base", shape = "cylinder", axis = "y", size = { 0.5, 1.4, 0.5 }, at = { 1.9, 3.1, 3.1 }, color = "metal" },

		{ name = "turret", parent = "base", shape = "box", size = { 3.8, 1.4, 3.6 }, at = { 0, 3.1, 0.6 }, color = "team" },
		{ name = "turretTop", parent = "turret", shape = "box", size = { 2.8, 0.4, 2.4 }, at = { 0, 4.0, 0.9 }, color = "dark" },
		{ name = "visor", parent = "turret", shape = "box", size = { 2.0, 0.25, 0.1 }, at = { 0, 3.35, -1.25 }, color = "glass" },

		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 3.0 }, at = { 0, 3.0, -2.6 }, pivot = { 0, 3.0, -1.1 }, color = "metal" },
		{ name = "brake", parent = "barrel", shape = "box", size = { 1.0, 1.0, 0.7 }, at = { 0, 3.0, -4.2 }, color = "dark" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 3.0, -4.6 } },
	},
}
