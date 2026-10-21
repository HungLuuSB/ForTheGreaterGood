--!strict
-- Warden (Order deployable gun, T2, footprint 1; def from S-64): a low heavy
-- hull with thick skirts, a big casemate turret and a long gun. The rear
-- `spades` (one hinged stabilizer plate) stand folded against the back plate
-- at rest (packed) and swing down onto the ground behind when deployed
-- (state bit DEPLOYED; review pose in Pending/Registry.luau). Order reads
-- heavy (M-14). Model space, forward = -Z (docs/contracts/rig.md).

return {
	id = "ord_warden",
	parts = {
		{ name = "base", shape = "box", size = { 5.4, 1.3, 7.0 }, at = { 0, 1.45, 0.3 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 5.4, 1.3, 1.2 }, at = { 0, 1.45, -3.8 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.1, 1.3, 7.8 }, at = { -2.7, 0.65, 0 }, color = "track" },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.1, 1.3, 7.8 }, at = { 2.7, 0.65, 0 }, color = "track" },
		{ name = "skirtL", parent = "base", shape = "box", size = { 0.35, 1.2, 7.4 }, at = { -3.4, 1.15, 0 }, color = "hull" },
		{ name = "skirtR", parent = "base", shape = "box", size = { 0.35, 1.2, 7.4 }, at = { 3.4, 1.15, 0 }, color = "hull" },
		{ name = "sideTeamL", parent = "base", shape = "box", size = { 0.06, 0.4, 3.6 }, at = { -3.6, 1.35, 0 }, color = "team" },
		{ name = "sideTeamR", parent = "base", shape = "box", size = { 0.06, 0.4, 3.6 }, at = { 3.6, 1.35, 0 }, color = "team" },
		{ name = "light", parent = "base", shape = "box", size = { 2.6, 0.12, 0.08 }, at = { 0, 1.25, -4.42 }, color = "glass" },

		{ name = "turret", parent = "base", shape = "box", size = { 4.2, 1.5, 4.4 }, at = { 0, 2.85, 0.9 }, pivot = { 0, 2.1, 0.9 }, color = "hull" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 4.2, 1.5, 1.2 }, at = { 0, 2.85, -1.9 }, color = "hull" },
		{ name = "roofTeam", parent = "turret", shape = "box", size = { 3.2, 0.08, 3.2 }, at = { 0, 3.64, 1.0 }, color = "team" },
		{ name = "sight", parent = "turret", shape = "box", size = { 0.6, 0.4, 0.6 }, at = { 1.4, 3.8, -0.2 }, color = "dark" },
		{ name = "sightGlass", parent = "turret", shape = "box", size = { 0.45, 0.18, 0.05 }, at = { 1.4, 3.8, -0.52 }, color = "glass" },

		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 7.2 }, at = { 0, 2.95, -5.3 }, pivot = { 0, 2.95, -1.7 }, color = "metal" },
		{ name = "brake", parent = "barrel", shape = "box", size = { 0.9, 0.7, 0.7 }, at = { 0, 2.95, -9.0 }, color = "dark" },

		-- spades: folded up against the back plate at rest, hinged at the bottom
		{ name = "spades", parent = "base", shape = "box", size = { 4.6, 2.2, 0.35 }, at = { 0, 1.9, 4.05 }, pivot = { 0, 0.8, 4.05 }, color = "dark" },
		{ name = "spadeTeam", parent = "spades", shape = "box", size = { 3.2, 0.3, 0.06 }, at = { 0, 2.4, 4.25 }, color = "team" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 2.95, -9.4 } },
	},
}
