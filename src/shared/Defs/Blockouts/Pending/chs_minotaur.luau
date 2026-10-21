--!strict
-- Minotaur (Chaos siege ram, T2, proposed footprint 2; docs/design/factions.md):
-- a heavy assault hull behind a huge angled ram plate studded with
-- reactive-armor blocks, exposed tracks, a squat turret with a short, fat
-- demolition gun, slat cage at the back. Chaos's one heavy unit, still
-- rugged and exposed rather than fortress-like. Model space, forward = -Z.

return {
	id = "chs_minotaur",
	parts = {
		{ name = "base", shape = "box", size = { 7, 2, 11 }, at = { 0, 2.0, 0.6 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.5, 1.9, 12.2 }, at = { -4.3, 0.95, 0.2 }, color = "track" },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.5, 1.9, 12.2 }, at = { 4.3, 0.95, 0.2 }, color = "track" },
		{ name = "ram", parent = "base", shape = "box", size = { 9.6, 2.8, 0.8 }, at = { 0, 1.9, -6.0 }, rot = { -30, 0, 0 }, color = "metal" },
		{ name = "ramBlockL", parent = "base", shape = "box", size = { 1.8, 1.0, 0.5 }, at = { -3, 2.0, -6.55 }, rot = { -30, 0, 0 }, color = "dark" },
		{ name = "ramBlockC", parent = "base", shape = "box", size = { 1.8, 1.0, 0.5 }, at = { 0, 2.0, -6.55 }, rot = { -30, 0, 0 }, color = "dark" },
		{ name = "ramBlockR", parent = "base", shape = "box", size = { 1.8, 1.0, 0.5 }, at = { 3, 2.0, -6.55 }, rot = { -30, 0, 0 }, color = "dark" },
		{ name = "deckTeamL", parent = "base", shape = "box", size = { 1.4, 0.1, 4 }, at = { -2.6, 3.05, 3.4 }, color = "team" },
		{ name = "deckTeamR", parent = "base", shape = "box", size = { 1.4, 0.1, 4 }, at = { 2.6, 3.05, 3.4 }, color = "team" },
		{ name = "cageTop", parent = "base", shape = "box", size = { 7.4, 0.15, 0.15 }, at = { 0, 2.9, 6.6 }, color = "dark" },
		{ name = "cageLow", parent = "base", shape = "box", size = { 7.4, 0.15, 0.15 }, at = { 0, 1.2, 6.6 }, color = "dark" },
		{ name = "cage1", parent = "base", shape = "box", size = { 0.12, 1.7, 0.12 }, at = { -2.4, 2.05, 6.6 }, color = "dark" },
		{ name = "cage2", parent = "base", shape = "box", size = { 0.12, 1.7, 0.12 }, at = { 0, 2.05, 6.6 }, color = "dark" },
		{ name = "cage3", parent = "base", shape = "box", size = { 0.12, 1.7, 0.12 }, at = { 2.4, 2.05, 6.6 }, color = "dark" },

		{ name = "turret", parent = "base", shape = "box", size = { 4.6, 1.6, 4.2 }, at = { 0, 3.8, 1.6 }, color = "hull" },
		{ name = "roofTeam", parent = "turret", shape = "box", size = { 3.2, 0.1, 2.8 }, at = { 0, 4.65, 1.8 }, color = "team" },
		{ name = "eyeL", parent = "turret", shape = "box", size = { 0.5, 0.3, 0.1 }, at = { -1.4, 4.2, -0.52 }, color = "glass" },
		{ name = "eyeR", parent = "turret", shape = "box", size = { 0.5, 0.3, 0.1 }, at = { 1.4, 4.2, -0.52 }, color = "glass" },

		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 1.6, 1.6, 3.2 }, at = { 0, 3.7, -1.6 }, pivot = { 0, 3.7, -0.3 }, color = "metal" },
		{ name = "lip", parent = "barrel", shape = "cylinder", axis = "z", size = { 2.0, 2.0, 0.5 }, at = { 0, 3.7, -3.3 }, color = "dark" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 3.7, -3.6 } },
	},
}
