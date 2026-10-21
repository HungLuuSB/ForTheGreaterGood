--!strict
-- Juggernaut (Chaos main battle tank, T2): a heavy tracked hull carrying a
-- turning torso with two gun arms at the shoulders (guide 14.4). The arms
-- hang down at rest and rise to fire, following the server's aim (S-20,
-- Core/PieceScripts/chs_juggernaut, C-33). Model space, forward = -Z
-- (docs/contracts/rig.md).

return {
	id = "chs_juggernaut",
	parts = {
		{ name = "base", shape = "box", size = { 6.2, 1.7, 7.4 }, at = { 0, 1.75, 0.1 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 6.2, 1.0, 1.6 }, at = { 0, 2.1, -3.4 }, rot = { 0, 180, 0 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.5, 1.7, 8.0 }, at = { -3.3, 0.85, 0 }, color = "track" },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.5, 1.7, 8.0 }, at = { 3.3, 0.85, 0 }, color = "track" },
		{ name = "skirtL", parent = "base", shape = "box", size = { 0.35, 1.2, 7.0 }, at = { -4.15, 1.65, 0.1 }, color = "dark" },
		{ name = "skirtR", parent = "base", shape = "box", size = { 0.35, 1.2, 7.0 }, at = { 4.15, 1.65, 0.1 }, color = "dark" },
		{ name = "stackL", parent = "base", shape = "cylinder", axis = "y", size = { 0.6, 1.8, 0.6 }, at = { -2.2, 3.4, 3.2 }, color = "metal" },
		{ name = "stackR", parent = "base", shape = "cylinder", axis = "y", size = { 0.6, 1.8, 0.6 }, at = { 2.2, 3.4, 3.2 }, color = "metal" },
		{ name = "ring", parent = "base", shape = "cylinder", axis = "y", size = { 3.4, 0.4, 3.4 }, at = { 0, 2.8, 0.3 }, color = "dark" },

		-- torso: turns on the ring (the def's turret piece)
		{ name = "turret", parent = "base", shape = "box", size = { 3.4, 2.4, 3.0 }, at = { 0, 4.2, 0.4 }, pivot = { 0, 3.0, 0.3 }, color = "team" },
		{ name = "head", parent = "turret", shape = "box", size = { 1.8, 1.0, 1.6 }, at = { 0, 5.9, 0.1 }, color = "dark" },
		{ name = "visor", parent = "turret", shape = "box", size = { 1.4, 0.3, 0.1 }, at = { 0, 6.0, -0.72 }, color = "glass" },
		{ name = "padL", parent = "turret", shape = "box", size = { 1.2, 0.6, 1.8 }, at = { -2.1, 5.55, 0.3 }, color = "dark" },
		{ name = "padR", parent = "turret", shape = "box", size = { 1.2, 0.6, 1.8 }, at = { 2.1, 5.55, 0.3 }, color = "dark" },

		-- gun arms: pivot at the shoulder, pointing forward at pitch 0
		{ name = "armL", parent = "turret", shape = "box", size = { 1.0, 1.0, 3.2 }, at = { -2.3, 4.6, -1.0 }, pivot = { -2.3, 4.6, 0.4 }, color = "hull" },
		{ name = "gunL", parent = "armL", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 2.4 }, at = { -2.3, 4.6, -3.6 }, color = "metal" },
		{ name = "brakeL", parent = "armL", shape = "box", size = { 0.9, 0.9, 0.5 }, at = { -2.3, 4.6, -4.9 }, color = "dark" },
		{ name = "armR", parent = "turret", shape = "box", size = { 1.0, 1.0, 3.2 }, at = { 2.3, 4.6, -1.0 }, pivot = { 2.3, 4.6, 0.4 }, color = "hull" },
		{ name = "gunR", parent = "armR", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 2.4 }, at = { 2.3, 4.6, -3.6 }, color = "metal" },
		{ name = "brakeR", parent = "armR", shape = "box", size = { 0.9, 0.9, 0.5 }, at = { 2.3, 4.6, -4.9 }, color = "dark" },
	},
	attachments = {
		{ name = "muzzle", parent = "armR", at = { 2.3, 4.6, -5.2 } },
	},
}
