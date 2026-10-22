--!strict
-- Warden (Order deployable gun, T2, footprint 1; def from S-64): a low heavy
-- hull with thick skirts, a big casemate turret and a long gun. Packed and
-- deployed must read apart at 220 studs (review 2026-10-22):
--   packed: big rear `spades` plate standing folded behind the turret, two
--     tall shield wings (`shieldL`, `shieldR`) stowed along the hull sides,
--     four `jacks` pads raised beside the tracks, gun level;
--   deployed: the hull squats 0.4 onto the jacks (base down, jacks down
--     0.5 more to the ground), the spades swing 100° back onto the ground,
--     the wings swing 90° forward into a wall wider than the hull with a slot
--     for the gun, and the gun rises.
-- Review poses: Pending/Registry.luau; the client's piece script animates it
-- (models progress, Requests). Order reads heavy (M-14). Model space,
-- forward = -Z (docs/contracts/rig.md).

return {
	id = "ord_warden",
	visualPieces = { "jacks", "shieldL", "shieldR" },
	parts = {
		{ name = "base", shape = "box", size = { 5.4, 1.3, 7.0 }, at = { 0, 1.45, 0.3 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 5.4, 1.3, 1.2 }, at = { 0, 1.45, -3.8 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.1, 1.3, 7.8 }, at = { -2.7, 0.65, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.1, 1.3, 7.8 }, at = { 2.7, 0.65, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "skirtL", parent = "base", shape = "box", size = { 0.35, 1.2, 7.4 }, at = { -3.4, 1.15, 0 }, color = "hull" },
		{ name = "skirtR", parent = "base", shape = "box", size = { 0.35, 1.2, 7.4 }, at = { 3.4, 1.15, 0 }, color = "hull" },
		{ name = "light", parent = "base", shape = "box", size = { 2.6, 0.12, 0.08 }, at = { 0, 1.25, -4.42 }, color = "glass" },

		{ name = "turret", parent = "base", shape = "box", size = { 4.2, 1.5, 4.4 }, at = { 0, 2.85, 0.9 }, pivot = { 0, 2.1, 0.9 }, color = "hull" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 4.2, 1.5, 1.2 }, at = { 0, 2.85, -1.9 }, color = "hull" },
		{ name = "roofTeam", parent = "turret", shape = "box", size = { 3.2, 0.08, 3.2 }, at = { 0, 3.64, 1.0 }, color = "team" },
		{ name = "sight", parent = "turret", shape = "box", size = { 0.6, 0.4, 0.6 }, at = { 1.4, 3.8, -0.2 }, color = "dark" },
		{ name = "sightGlass", parent = "turret", shape = "box", size = { 0.45, 0.18, 0.05 }, at = { 1.4, 3.8, -0.52 }, color = "glass" },

		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 7.2 }, at = { 0, 2.95, -5.3 }, pivot = { 0, 2.95, -1.7 }, color = "metal" },
		{ name = "brake", parent = "barrel", shape = "box", size = { 0.9, 0.7, 0.7 }, at = { 0, 2.95, -9.0 }, color = "dark" },

		-- spades: one wide plate hinged at the bottom of the back plate; packed
		-- it stands up behind the turret, deployed it lies on the ground behind
		-- (its front face carries hazard stripes: behind the turret when packed,
		-- face up on the ground when deployed: the cue that reads from the game camera)
		{ name = "spades", parent = "base", shape = "box", size = { 5.8, 3.2, 0.35 }, at = { 0, 2.4, 4.05 }, pivot = { 0, 0.8, 4.05 }, color = "dark" },
		{ name = "spadeTeeth", parent = "spades", shape = "box", size = { 5.8, 0.3, 0.6 }, at = { 0, 3.85, 4.05 }, color = "metal" },
		{ name = "spadeTeam", parent = "spades", shape = "box", size = { 3.6, 0.5, 0.06 }, at = { 0, 2.5, 4.25 }, color = "team" },

		{ name = "spadeHazard0", parent = "spades", shape = "box", size = { 0.72, 2.05, 0.06 }, at = { -2.16, 1.975, 3.85 }, color = "hazard" },
		{ name = "spadeHazard1", parent = "spades", shape = "box", size = { 0.72, 2.05, 0.06 }, at = { -0.72, 1.975, 3.85 }, color = "hazard" },
		{ name = "spadeHazard2", parent = "spades", shape = "box", size = { 0.72, 2.05, 0.06 }, at = { 0.72, 1.975, 3.85 }, color = "hazard" },
		{ name = "spadeHazard3", parent = "spades", shape = "box", size = { 0.72, 2.05, 0.06 }, at = { 2.16, 1.975, 3.85 }, color = "hazard" },

		-- shield wings: hinged on vertical axes at the hull's front corners;
		-- packed they lie along the sides, deployed they meet in front with a
		-- gun slot (1.3 studs) between them; hazard stripes on the inner faces
		-- (against the hull when packed, facing forward when deployed)
		{ name = "shieldL", parent = "base", shape = "box", size = { 0.3, 2.8, 3.2 }, at = { -3.85, 2.0, -2.9 }, pivot = { -3.85, 2.0, -4.5 }, color = "hull" },
		{ name = "shieldTeamL", parent = "shieldL", shape = "box", size = { 0.06, 0.5, 2.4 }, at = { -4.03, 2.9, -2.9 }, color = "team" },
		{ name = "shieldHazardL0", parent = "shieldL", shape = "box", size = { 0.06, 1.3, 0.7 }, at = { -3.67, 1.35, -4.0 }, color = "hazard" },
		{ name = "shieldHazardL1", parent = "shieldL", shape = "box", size = { 0.06, 1.3, 0.7 }, at = { -3.67, 1.35, -2.9 }, color = "hazard" },
		{ name = "shieldHazardL2", parent = "shieldL", shape = "box", size = { 0.06, 1.3, 0.7 }, at = { -3.67, 1.35, -1.8 }, color = "hazard" },
		{ name = "shieldR", parent = "base", shape = "box", size = { 0.3, 2.8, 3.2 }, at = { 3.85, 2.0, -2.9 }, pivot = { 3.85, 2.0, -4.5 }, color = "hull" },
		{ name = "shieldTeamR", parent = "shieldR", shape = "box", size = { 0.06, 0.5, 2.4 }, at = { 4.03, 2.9, -2.9 }, color = "team" },

		{ name = "shieldHazardR0", parent = "shieldR", shape = "box", size = { 0.06, 1.3, 0.7 }, at = { 3.67, 1.35, -4.0 }, color = "hazard" },
		{ name = "shieldHazardR1", parent = "shieldR", shape = "box", size = { 0.06, 1.3, 0.7 }, at = { 3.67, 1.35, -2.9 }, color = "hazard" },
		{ name = "shieldHazardR2", parent = "shieldR", shape = "box", size = { 0.06, 1.3, 0.7 }, at = { 3.67, 1.35, -1.8 }, color = "hazard" },

		-- jacks: four legs with pads beside the tracks, raised 0.9 when packed
		{ name = "jacks", parent = "base", shape = "box", size = { 0.3, 0.95, 0.3 }, at = { -3.9, 1.525, -0.6 }, color = "dark" },
		{ name = "jackFR", parent = "jacks", shape = "box", size = { 0.3, 0.95, 0.3 }, at = { 3.9, 1.525, -0.6 }, color = "dark" },
		{ name = "jackBL", parent = "jacks", shape = "box", size = { 0.3, 0.95, 0.3 }, at = { -3.9, 1.525, 2.9 }, color = "dark" },
		{ name = "jackBR", parent = "jacks", shape = "box", size = { 0.3, 0.95, 0.3 }, at = { 3.9, 1.525, 2.9 }, color = "dark" },
		{ name = "padFL", parent = "jacks", shape = "box", size = { 0.8, 0.15, 0.8 }, at = { -3.9, 0.975, -0.6 }, color = "metal" },
		{ name = "padFR", parent = "jacks", shape = "box", size = { 0.8, 0.15, 0.8 }, at = { 3.9, 0.975, -0.6 }, color = "metal" },
		{ name = "padBL", parent = "jacks", shape = "box", size = { 0.8, 0.15, 0.8 }, at = { -3.9, 0.975, 2.9 }, color = "metal" },
		{ name = "padBR", parent = "jacks", shape = "box", size = { 0.8, 0.15, 0.8 }, at = { 3.9, 0.975, 2.9 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 2.95, -9.4 } },
	},
}
