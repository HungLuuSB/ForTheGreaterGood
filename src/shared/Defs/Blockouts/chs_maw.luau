--!strict
-- Maw (Chaos heavy turret, T2, footprint 1): a round base with reactive
-- blocks, a squat wide turret with a very fat short gun (the "maw") and a
-- glowing ring inside its mouth, team plate on the roof.
-- Model space, forward = -Z.

return {
	id = "chs_maw",
	parts = {
		{ name = "base", shape = "cylinder", axis = "y", size = { 6, 1.4, 6 }, at = { 0, 0.7, 0 }, color = "dark" },
		{ name = "eraA", parent = "base", shape = "box", size = { 1.8, 1, 0.3 }, at = { 0, 1, -3.05 }, color = "metal" },
		{ name = "eraB", parent = "base", shape = "box", size = { 1.8, 1, 0.3 }, at = { -2.35, 1, -1.95 }, rot = { 0, 50, 0 }, color = "metal" },
		{ name = "eraC", parent = "base", shape = "box", size = { 1.8, 1, 0.3 }, at = { 2.35, 1, -1.95 }, rot = { 0, -50, 0 }, color = "metal" },

		-- T2: the turret rides a tall drum above the Spike's height (T1 vs T2 check, 2026-10-22)
		{ name = "drum", parent = "base", shape = "cylinder", axis = "y", size = { 4, 1.4, 4 }, at = { 0, 2.1, 0 }, color = "hull" },
		{ name = "eraD", parent = "base", shape = "box", size = { 1.8, 1, 0.3 }, at = { -2.35, 1, 1.95 }, rot = { 0, -50, 0 }, color = "metal" },
		{ name = "eraE", parent = "base", shape = "box", size = { 1.8, 1, 0.3 }, at = { 2.35, 1, 1.95 }, rot = { 0, 50, 0 }, color = "metal" },
		{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 4.6, 2, 4.6 }, at = { 0, 3.8, 0.2 }, pivot = { 0, 2.8, 0 }, color = "hull" },
		{ name = "roofTeam", parent = "turret", shape = "box", size = { 2.8, 0.1, 2.4 }, at = { 0, 4.85, 0.6 }, color = "team" },
		{ name = "gun", parent = "turret", shape = "cylinder", axis = "z", size = { 1.6, 1.6, 3.6 }, at = { 0, 4, -3.4 }, color = "metal" },
		{ name = "mouth", parent = "turret", shape = "cylinder", axis = "z", size = { 2.1, 2.1, 0.6 }, at = { 0, 4, -5.1 }, color = "dark" },
		{ name = "glow", parent = "turret", shape = "cylinder", axis = "z", size = { 1.1, 1.1, 0.1 }, at = { 0, 4, -5.42 }, color = "glass" },
		{ name = "ammoDrum", parent = "turret", shape = "cylinder", axis = "x", size = { 1.2, 1.8, 1.8 }, at = { 2.7, 3.8, 0.6 }, color = "metal" },
		{ name = "ammoFeed", parent = "turret", shape = "box", size = { 0.6, 0.5, 1.4 }, at = { 2.2, 4.4, -0.3 }, color = "dark" },
	},
	attachments = {
		{ name = "muzzle", parent = "turret", at = { 0, 4, -5.5 } },
	},
}
