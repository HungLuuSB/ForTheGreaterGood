--!strict
-- Citadel (Order fortress, T3 structure, proposed footprint 3;
-- docs/design/factions.md): a stepped armored block with sloped blast walls,
-- a big turret with a long gun on top, an IR SAM launcher on a corner
-- pedestal and a flat radar array on a mast at the opposite corner.
-- Model space, forward = -Z.

return {
	id = "ord_citadel",
	parts = {
		{ name = "base", shape = "box", size = { 20, 2, 20 }, at = { 0, 1, 0 }, color = "hull" },
		{ name = "wallF", parent = "base", shape = "wedge", size = { 20, 2, 2 }, at = { 0, 1, -11 }, color = "hull" },
		{ name = "wallB", parent = "base", shape = "wedge", size = { 20, 2, 2 }, at = { 0, 1, 11 }, rot = { 0, 180, 0 }, color = "hull" },
		{ name = "wallL", parent = "base", shape = "wedge", size = { 20, 2, 2 }, at = { -11, 1, 0 }, rot = { 0, 90, 0 }, color = "hull" },
		{ name = "wallR", parent = "base", shape = "wedge", size = { 20, 2, 2 }, at = { 11, 1, 0 }, rot = { 0, -90, 0 }, color = "hull" },
		{ name = "block", parent = "base", shape = "box", size = { 14, 2.4, 14 }, at = { 0, 3.2, 0 }, color = "hull" },
		{ name = "teamF", parent = "base", shape = "box", size = { 12, 0.1, 2 }, at = { 0, 2.06, -8.5 }, color = "team" },
		{ name = "teamB", parent = "base", shape = "box", size = { 12, 0.1, 2 }, at = { 0, 2.06, 8.5 }, color = "team" },
		{ name = "pedestal", parent = "base", shape = "box", size = { 1.8, 1.4, 1.8 }, at = { -5.6, 5.1, -5.6 }, color = "dark" },
		{ name = "mast", parent = "base", shape = "box", size = { 0.6, 1.8, 0.6 }, at = { 5.6, 5.3, 5.6 }, color = "dark" },
		{ name = "lightNW", parent = "base", shape = "box", size = { 0.7, 0.7, 0.7 }, at = { -9.3, 2.3, -9.3 }, color = "glass" },
		{ name = "lightNE", parent = "base", shape = "box", size = { 0.7, 0.7, 0.7 }, at = { 9.3, 2.3, -9.3 }, color = "glass" },
		{ name = "lightSW", parent = "base", shape = "box", size = { 0.7, 0.7, 0.7 }, at = { -9.3, 2.3, 9.3 }, color = "glass" },
		{ name = "lightSE", parent = "base", shape = "box", size = { 0.7, 0.7, 0.7 }, at = { 9.3, 2.3, 9.3 }, color = "glass" },

		{ name = "turret", parent = "base", shape = "box", size = { 8, 2.6, 8 }, at = { 0, 5.7, 0.5 }, pivot = { 0, 4.4, 0.5 }, color = "hull" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 8, 2.6, 2 }, at = { 0, 5.7, -4.5 }, color = "hull" },
		{ name = "roofTeam", parent = "turret", shape = "box", size = { 6, 0.1, 6 }, at = { 0, 7.05, 0.8 }, color = "team" },
		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 1.2, 1.2, 11 }, at = { 0, 5.9, -9.5 }, pivot = { 0, 5.9, -4.0 }, color = "metal" },

		{ name = "launcher", parent = "base", shape = "box", size = { 2.8, 1.6, 3 }, at = { -5.6, 6.6, -5.6 }, pivot = { -5.6, 5.8, -5.6 }, color = "metal" },
		{ name = "launcherCaps", parent = "launcher", shape = "box", size = { 2.4, 1.2, 0.1 }, at = { -5.6, 6.6, -7.12 }, color = "dark" },

		{ name = "radar", parent = "base", shape = "box", size = { 4.4, 2.8, 0.35 }, at = { 5.6, 7.6, 5.6 }, rot = { 20, 0, 0 }, pivot = { 5.6, 6.2, 5.6 }, color = "dark" },
		{ name = "radarFace", parent = "radar", shape = "box", size = { 4.0, 2.4, 0.1 }, at = { 5.6, 7.66, 5.38 }, rot = { 20, 0, 0 }, color = "glass" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 5.9, -15.1 } },
		{ name = "muzzle2", parent = "launcher", at = { -5.6, 6.6, -7.2 } },
	},
}
