--!strict
-- Warden (Order deployable gun, T2, proposed footprint 2; docs/design/factions.md):
-- a long tracked hull with thick skirts carrying a big casemate turret and a
-- long gun. Rest pose = packed: the rear spades stand folded against the
-- back plate and the shield lies flat on the front deck. Deploying turns the
-- spades down onto the ground behind and raises the shield in front of the
-- turret (poses in Pending/Registry.luau). Model space, forward = -Z.

return {
	id = "ord_warden",
	visualPieces = { "spadeL", "spadeR", "shield" },
	parts = {
		{ name = "base", shape = "box", size = { 8, 1.6, 12 }, at = { 0, 1.7, 0.4 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 8, 1.6, 2 }, at = { 0, 1.7, -6.6 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.6, 1.8, 13.4 }, at = { -4.7, 0.9, -0.2 }, color = "track" },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.6, 1.8, 13.4 }, at = { 4.7, 0.9, -0.2 }, color = "track" },
		{ name = "skirtL", parent = "base", shape = "box", size = { 0.45, 1.5, 12.4 }, at = { -5.75, 1.45, -0.2 }, color = "hull" },
		{ name = "skirtR", parent = "base", shape = "box", size = { 0.45, 1.5, 12.4 }, at = { 5.75, 1.45, -0.2 }, color = "hull" },
		{ name = "sideTeamL", parent = "base", shape = "box", size = { 0.08, 0.5, 6 }, at = { -6.0, 1.7, 0 }, color = "team" },
		{ name = "sideTeamR", parent = "base", shape = "box", size = { 0.08, 0.5, 6 }, at = { 6.0, 1.7, 0 }, color = "team" },
		{ name = "light", parent = "base", shape = "box", size = { 4, 0.15, 0.1 }, at = { 0, 1.3, -7.62 }, color = "glass" },

		{ name = "turret", parent = "base", shape = "box", size = { 6, 2, 6.4 }, at = { 0, 3.5, 1.4 }, pivot = { 0, 2.5, 1.4 }, color = "hull" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 6, 2, 1.6 }, at = { 0, 3.5, -2.6 }, color = "hull" },
		{ name = "roofTeam", parent = "turret", shape = "box", size = { 4.4, 0.1, 4.4 }, at = { 0, 4.55, 1.4 }, color = "team" },
		{ name = "sight", parent = "turret", shape = "box", size = { 0.9, 0.6, 0.9 }, at = { 2, 4.8, -0.4 }, color = "dark" },
		{ name = "sightGlass", parent = "turret", shape = "box", size = { 0.7, 0.25, 0.05 }, at = { 2, 4.8, -0.87 }, color = "glass" },

		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 10 }, at = { 0, 3.6, -7.2 }, pivot = { 0, 3.6, -2.2 }, color = "metal" },
		{ name = "brake", parent = "barrel", shape = "box", size = { 1.4, 1.1, 1 }, at = { 0, 3.6, -12.6 }, color = "dark" },

		-- deploy pieces, packed at rest
		{ name = "spadeL", parent = "base", shape = "box", size = { 2.6, 3, 0.4 }, at = { -2.4, 2.5, 6.8 }, pivot = { -2.4, 1.0, 6.8 }, color = "dark" },
		{ name = "spadeR", parent = "base", shape = "box", size = { 2.6, 3, 0.4 }, at = { 2.4, 2.5, 6.8 }, pivot = { 2.4, 1.0, 6.8 }, color = "dark" },
		{ name = "shield", parent = "base", shape = "box", size = { 7, 0.35, 2.4 }, at = { 0, 2.68, -4.4 }, pivot = { 0, 2.5, -5.6 }, color = "hull" },
		{ name = "shieldTeam", parent = "shield", shape = "box", size = { 5, 0.08, 1.2 }, at = { 0, 2.89, -4.4 }, color = "team" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 3.6, -13.2 } },
	},
}
