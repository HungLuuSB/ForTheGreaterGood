--!strict
-- Cyclops (Chaos siege mortar, T2, footprint 2; def S-75): tall (review
-- 2026-10-22: it must differ from the low, wide Minotaur as a black shape).
-- A narrow tracked hull with a recoil spade and an open casemate carrying
-- one huge mortar tube, near-vertical (75°), and the single big glowing
-- sensor "eye" up on a raised mast beside it; slat cage at the back.
-- The tube is fixed to the turret (a mortar ranges by charge): the weapon
-- pitches from -5° to 60° from a level rest (rig.md 2), so the `barrel` is
-- the short elevating cradle at the tube's foot, and the muzzle sits at the
-- tube's mouth on the turret. Model space, forward = -Z.

return {
	id = "chs_cyclops",
	parts = {
		{ name = "base", shape = "box", size = { 6.0, 1.6, 10 }, at = { 0, 1.8, 0.5 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.3, 1.8, 11 }, at = { -3.7, 0.9, 0.3 }, color = "track" },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.3, 1.8, 11 }, at = { 3.7, 0.9, 0.3 }, color = "track" },
		{ name = "spade", parent = "base", shape = "box", size = { 5.6, 1.8, 0.4 }, at = { 0, 1.2, 6.0 }, rot = { 25, 0, 0 }, color = "dark" },
		{ name = "deckTeamL", parent = "base", shape = "box", size = { 1.3, 0.1, 3.0 }, at = { -2.1, 2.65, -2.8 }, color = "team" },
		{ name = "deckTeamR", parent = "base", shape = "box", size = { 1.3, 0.1, 3.0 }, at = { 2.1, 2.65, -2.8 }, color = "team" },
		{ name = "cageTop", parent = "base", shape = "box", size = { 6.2, 0.12, 0.12 }, at = { 0, 2.8, 5.6 }, color = "dark" },
		{ name = "cage1", parent = "base", shape = "box", size = { 0.1, 1.2, 0.1 }, at = { -2, 2.2, 5.6 }, color = "dark" },
		{ name = "cage2", parent = "base", shape = "box", size = { 0.1, 1.2, 0.1 }, at = { 0, 2.2, 5.6 }, color = "dark" },
		{ name = "cage3", parent = "base", shape = "box", size = { 0.1, 1.2, 0.1 }, at = { 2, 2.2, 5.6 }, color = "dark" },

		{ name = "turret", parent = "base", shape = "box", size = { 4.6, 1.4, 4.6 }, at = { 0, 3.3, 1.0 }, color = "hull" },
		{ name = "pit", parent = "turret", shape = "box", size = { 3.0, 0.1, 1.6 }, at = { 0, 4.05, 2.4 }, color = "team" },
		-- the tube: 7 long, 2 wide, from its foot at (0, 3.6, 1.0) up and forward
		{ name = "tube", parent = "turret", shape = "cylinder", axis = "z", size = { 2.0, 2.0, 7.0 }, at = { 0, 6.98, 0.09 }, rot = { 75, 0, 0 }, color = "metal" },
		{ name = "tubeBand", parent = "turret", shape = "cylinder", axis = "z", size = { 2.3, 2.3, 0.4 }, at = { 0, 5.3, 0.55 }, rot = { 75, 0, 0 }, color = "dark" },
		{ name = "rim", parent = "turret", shape = "cylinder", axis = "z", size = { 2.5, 2.5, 0.5 }, at = { 0, 10.27, -0.79 }, rot = { 75, 0, 0 }, color = "dark" },
		-- the eye: a big glowing ball on a braced mast, hooded
		{ name = "mast", parent = "turret", shape = "box", size = { 0.4, 4.6, 0.4 }, at = { -2.6, 6.3, -0.6 }, color = "dark" },
		{ name = "mastBrace", parent = "turret", shape = "box", size = { 0.2, 3.6, 0.2 }, at = { -2.1, 5.6, -0.6 }, rot = { 0, 0, -12 }, color = "dark" },
		{ name = "eye", parent = "turret", shape = "ball", size = { 1.9, 1.9, 1.9 }, at = { -2.6, 9.2, -0.6 }, color = "glass" },
		{ name = "eyeHood", parent = "turret", shape = "box", size = { 2.3, 0.4, 2.0 }, at = { -2.6, 10.3, -0.4 }, color = "dark" },

		-- barrel: the elevating cradle at the tube's foot (pitch and recoil)
		{ name = "barrel", parent = "turret", shape = "box", size = { 2.6, 1.0, 1.6 }, at = { 0, 4.3, 1.0 }, pivot = { 0, 4.3, 1.0 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "turret", at = { 0, 10.45, -0.85 } },
	},
}
