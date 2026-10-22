--!strict
-- Minotaur (Chaos siege ram, T2, footprint 2; def from S-64): a low, wide,
-- front-heavy wedge (review 2026-10-22: it must differ from the tall Cyclops
-- as a black shape). A long sloped glacis rises to a flat, low turret pushed
-- forward with a short fat demolition gun over a low flat deck;
-- in front, the `ram` plate (jointed: the demolition charge turns it toward
-- its target and fires from it) is wider than the tracks, studded with
-- reactive-armor blocks. Exposed tracks, slat cage low at the back.
-- Model space, forward = -Z (docs/contracts/rig.md).

return {
	id = "chs_minotaur",
	parts = {
		{ name = "base", shape = "box", size = { 7.6, 1.5, 8 }, at = { 0, 1.55, 1.4 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 7.6, 1.5, 3.6 }, at = { 0, 1.55, -4.4 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.6, 1.7, 12 }, at = { -4.6, 0.85, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.6, 1.7, 12 }, at = { 4.6, 0.85, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },

		-- ram: 11.8 wide, wider than the tracks (10.8), its top leaning forward
		{ name = "ram", parent = "base", shape = "box", size = { 11.8, 2.4, 0.8 }, at = { 0, 1.5, -6.9 }, rot = { -25, 0, 0 }, pivot = { 0, 1.5, -6.4 }, color = "metal" },
		{ name = "ramBlockL", parent = "ram", shape = "box", size = { 2.2, 1.0, 0.5 }, at = { -3.6, 1.6, -7.45 }, rot = { -25, 0, 0 }, color = "dark" },
		{ name = "ramBlockC", parent = "ram", shape = "box", size = { 2.2, 1.0, 0.5 }, at = { 0, 1.6, -7.45 }, rot = { -25, 0, 0 }, color = "dark" },
		{ name = "ramBlockR", parent = "ram", shape = "box", size = { 2.2, 1.0, 0.5 }, at = { 3.6, 1.6, -7.45 }, rot = { -25, 0, 0 }, color = "dark" },
		{ name = "ramTipL", parent = "ram", shape = "wedge", size = { 0.8, 2.4, 1.2 }, at = { -5.5, 1.5, -7.6 }, color = "dark" },
		{ name = "ramTipR", parent = "ram", shape = "wedge", size = { 0.8, 2.4, 1.2 }, at = { 5.5, 1.5, -7.6 }, color = "dark" },

		{ name = "deckTeamL", parent = "base", shape = "box", size = { 1.6, 0.1, 3.4 }, at = { -2.7, 2.35, 2.2 }, color = "team" },
		{ name = "deckTeamR", parent = "base", shape = "box", size = { 1.6, 0.1, 3.4 }, at = { 2.7, 2.35, 2.2 }, color = "team" },
		{ name = "cageTop", parent = "base", shape = "box", size = { 7.4, 0.15, 0.15 }, at = { 0, 2.1, 5.7 }, color = "dark" },
		{ name = "cage1", parent = "base", shape = "box", size = { 0.12, 1.2, 0.12 }, at = { -2.4, 1.5, 5.7 }, color = "dark" },
		{ name = "cage2", parent = "base", shape = "box", size = { 0.12, 1.2, 0.12 }, at = { 0, 1.5, 5.7 }, color = "dark" },
		{ name = "cage3", parent = "base", shape = "box", size = { 0.12, 1.2, 0.12 }, at = { 2.4, 1.5, 5.7 }, color = "dark" },

		-- turret: flat and low, pushed forward over the glacis
		{ name = "turret", parent = "base", shape = "box", size = { 5.0, 1.0, 4.0 }, at = { 0, 2.8, -0.6 }, color = "hull" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 5.0, 1.0, 1.2 }, at = { 0, 2.8, -3.2 }, color = "hull" },
		{ name = "roofTeam", parent = "turret", shape = "box", size = { 3.4, 0.1, 2.8 }, at = { 0, 3.35, -0.4 }, color = "team" },
		{ name = "eyeL", parent = "turret", shape = "box", size = { 0.5, 0.25, 0.1 }, at = { -1.6, 3.0, -3.85 }, color = "glass" },
		{ name = "eyeR", parent = "turret", shape = "box", size = { 0.5, 0.25, 0.1 }, at = { 1.6, 3.0, -3.85 }, color = "glass" },

		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 1.5, 1.5, 2.6 }, at = { 0, 2.8, -4.4 }, pivot = { 0, 2.8, -3.4 }, color = "metal" },
		{ name = "lip", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.9, 1.9, 0.4 }, at = { 0, 2.8, -5.7 }, color = "dark" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 2.8, -5.95 } },
	},
}
