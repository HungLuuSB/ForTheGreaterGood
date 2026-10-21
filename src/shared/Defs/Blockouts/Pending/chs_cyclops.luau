--!strict
-- Cyclops (Chaos siege mortar, T2, proposed footprint 2; docs/design/factions.md):
-- a light tracked hull with a recoil spade, an open casemate carrying one
-- huge, fat mortar tube and a single big glowing sensor "eye" beside it,
-- a slat cage at the back. Model space, forward = -Z.

return {
	id = "chs_cyclops",
	parts = {
		{ name = "base", shape = "box", size = { 6.6, 1.6, 10 }, at = { 0, 1.9, 0.5 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.4, 1.8, 11 }, at = { -4.0, 0.9, 0.3 }, color = "track" },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.4, 1.8, 11 }, at = { 4.0, 0.9, 0.3 }, color = "track" },
		{ name = "spade", parent = "base", shape = "box", size = { 6, 1.8, 0.4 }, at = { 0, 1.2, 6.0 }, rot = { 25, 0, 0 }, color = "dark" },
		{ name = "deckTeamL", parent = "base", shape = "box", size = { 1.3, 0.1, 3.6 }, at = { -2.4, 2.75, -2.4 }, color = "team" },
		{ name = "deckTeamR", parent = "base", shape = "box", size = { 1.3, 0.1, 3.6 }, at = { 2.4, 2.75, -2.4 }, color = "team" },
		{ name = "cageTop", parent = "base", shape = "box", size = { 6.8, 0.12, 0.12 }, at = { 0, 2.8, 5.6 }, color = "dark" },
		{ name = "cage1", parent = "base", shape = "box", size = { 0.1, 1.2, 0.1 }, at = { -2, 2.2, 5.6 }, color = "dark" },
		{ name = "cage2", parent = "base", shape = "box", size = { 0.1, 1.2, 0.1 }, at = { 0, 2.2, 5.6 }, color = "dark" },
		{ name = "cage3", parent = "base", shape = "box", size = { 0.1, 1.2, 0.1 }, at = { 2, 2.2, 5.6 }, color = "dark" },

		{ name = "turret", parent = "base", shape = "box", size = { 5.2, 1.6, 5 }, at = { 0, 3.5, 1.2 }, color = "hull" },
		{ name = "pit", parent = "turret", shape = "box", size = { 3.4, 0.1, 2.6 }, at = { 0, 4.32, 2.0 }, color = "team" },
		{ name = "eye", parent = "turret", shape = "ball", size = { 1.5, 1.5, 1.5 }, at = { -2.0, 4.6, -0.9 }, color = "glass" },
		{ name = "eyeHood", parent = "turret", shape = "box", size = { 1.8, 0.4, 1.4 }, at = { -2.0, 5.45, -0.8 }, color = "dark" },

		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 2.4, 2.4, 4.4 }, at = { 0, 4.1, -1.6 }, pivot = { 0, 4.1, 0.6 }, color = "metal" },
		{ name = "rim", parent = "barrel", shape = "cylinder", axis = "z", size = { 3.0, 3.0, 0.6 }, at = { 0, 4.1, -3.7 }, color = "dark" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 4.1, -4.0 } },
	},
}
