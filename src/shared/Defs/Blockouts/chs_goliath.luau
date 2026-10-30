--!strict
-- Goliath (Chaos main battle tank, T2; back in S-224, re-modelled
-- 2026-10-30): a hunched giant. A wide tracked hull with a spiked ram, a
-- low torso with a forward-thrust head, and two gun arms on tall shoulder
-- pylons (guide 14.4). The arms hang down beside the tracks at rest and
-- rise to fire, following the server's aim (S-20,
-- Core/PieceScripts/chs_goliath, C-33). Model space, forward = -Z
-- (docs/contracts/rig.md).

return {
	id = "chs_goliath",
	parts = {
		{ name = "base", shape = "box", size = { 4.8, 1.9, 9.4 }, at = { 0, 1.45, 0 }, color = "hull" },
		{ name = "deck", parent = "base", shape = "box", size = { 6.6, 0.6, 9.4 }, at = { 0, 2.1, 0 }, color = "hull" },
		{ name = "ram", parent = "base", shape = "wedge", size = { 6.2, 1.4, 0.9 }, at = { 0, 1.25, -5.2 }, rot = { 0, 180, 0 }, color = "metal" },
		{ name = "trackL", parent = "base", shape = "box", size = { 0.9, 1.0, 9.4 }, at = { -2.85, 0.5, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "trackR", parent = "base", shape = "box", size = { 0.9, 1.0, 9.4 }, at = { 2.85, 0.5, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "stackL", parent = "base", shape = "cylinder", axis = "y", size = { 0.52, 1.8, 0.52 }, at = { -2.3, 3.3, 3.9 }, color = "dark" },
		{ name = "stackR", parent = "base", shape = "cylinder", axis = "y", size = { 0.52, 1.8, 0.52 }, at = { 2.3, 3.3, 3.9 }, color = "dark" },
		{ name = "ring", parent = "base", shape = "cylinder", axis = "y", size = { 4.6, 0.16, 4.6 }, at = { 0, 2.48, 0.2 }, color = "dark" },

		-- torso: turns on the ring (the def's turret piece)
		{ name = "turret", parent = "base", shape = "box", size = { 5.0, 2.4, 5.4 }, at = { 0, 3.7, 0.5 }, pivot = { 0, 2.4, 0.2 }, color = "hull" },
		{ name = "roof", parent = "turret", shape = "box", size = { 3.0, 0.06, 2.8 }, at = { 0, 4.93, 0.6 }, color = "team" },
		{ name = "head", parent = "turret", shape = "box", size = { 2.0, 1.4, 1.6 }, at = { 0, 4.1, -2.6 }, color = "hull" },
		{ name = "eyes", parent = "turret", shape = "box", size = { 1.5, 0.18, 0.06 }, at = { 0, 4.05, -3.42 }, color = "glass" },
		{ name = "bustle", parent = "turret", shape = "box", size = { 3.2, 1.4, 0.9 }, at = { 0, 3.9, 3.55 }, color = "hull" },
		{ name = "pylonL", parent = "turret", shape = "box", size = { 1.2, 1.6, 1.7 }, at = { -2.8, 4.9, 0.2 }, color = "hull" },
		{ name = "pylonR", parent = "turret", shape = "box", size = { 1.2, 1.6, 1.7 }, at = { 2.8, 4.9, 0.2 }, color = "hull" },

		-- gun arms: pivot at the shoulder, pointing forward at pitch 0
		{ name = "armL", parent = "turret", shape = "box", size = { 1.1, 1.1, 3.1 }, at = { -4.0, 5.5, -1.35 }, pivot = { -4.0, 5.5, 0.2 }, color = "hull" },
		{ name = "hoodL", parent = "armL", shape = "box", size = { 1.25, 0.75, 2.0 }, at = { -4.07, 6.15, 0.05 }, color = "team" },
		{ name = "gunL", parent = "armL", shape = "cylinder", axis = "z", size = { 0.64, 0.64, 1.8 }, at = { -4.0, 5.5, -3.7 }, color = "metal" },
		{ name = "fistL", parent = "armL", shape = "box", size = { 1.0, 0.9, 0.9 }, at = { -4.0, 5.5, -5.0 }, color = "dark" },
		{ name = "armR", parent = "turret", shape = "box", size = { 1.1, 1.1, 3.1 }, at = { 4.0, 5.5, -1.35 }, pivot = { 4.0, 5.5, 0.2 }, color = "hull" },
		{ name = "hoodR", parent = "armR", shape = "box", size = { 1.25, 0.75, 2.0 }, at = { 4.07, 6.15, 0.05 }, color = "team" },
		{ name = "gunR", parent = "armR", shape = "cylinder", axis = "z", size = { 0.64, 0.64, 1.8 }, at = { 4.0, 5.5, -3.7 }, color = "metal" },
		{ name = "fistR", parent = "armR", shape = "box", size = { 1.0, 0.9, 0.9 }, at = { 4.0, 5.5, -5.0 }, color = "dark" },
	},
	attachments = {
		{ name = "muzzle", parent = "armR", at = { 4.0, 5.5, -5.5 } },
	},
}
