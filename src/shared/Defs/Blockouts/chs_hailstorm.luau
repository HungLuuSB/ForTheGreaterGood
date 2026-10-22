--!strict
-- Hailstorm (Chaos flak tower, T2, footprint 1; S-96): a squat plated base
-- with ammo crates under a round `turret` carrying three lighter flak guns
-- in a row, laid up at 40 degrees behind a slab shield, and an orange
-- spotter eye. The def turns only `turret`. Model space, forward = -Z.

return {
	id = "chs_hailstorm",
	parts = {
		{ name = "base", shape = "cylinder", axis = "y", size = { 6.2, 1.4, 6.2 }, at = { 0, 0.7, 0 }, color = "dark" },
		{ name = "crateL", parent = "base", shape = "box", size = { 1.4, 1, 1.2 }, at = { -2.2, 1.9, 1.6 }, color = "metal" },
		{ name = "crateR", parent = "base", shape = "box", size = { 1.2, 0.8, 1.4 }, at = { 2.3, 1.8, 1.4 }, color = "metal" },
		{ name = "team", parent = "base", shape = "box", size = { 2.4, 0.08, 0.9 }, at = { 0, 1.44, 2.5 }, color = "team" },
		{ name = "pedestal", parent = "base", shape = "cylinder", axis = "y", size = { 2.4, 1.2, 2.4 }, at = { 0, 2.0, 0 }, color = "hull" },

		{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 3.4, 1.2, 3.4 }, at = { 0, 3.2, 0.2 }, pivot = { 0, 2.6, 0 }, color = "hull" },
		{ name = "headTeam", parent = "turret", shape = "box", size = { 1.6, 0.08, 1.2 }, at = { 0, 3.84, 0.9 }, color = "team" },
		{ name = "slab", parent = "turret", shape = "box", size = { 3.4, 1.4, 0.4 }, at = { 0, 3.9, -1.3 }, rot = { -20, 0, 0 }, color = "hull" },
		{ name = "eye", parent = "turret", shape = "ball", size = { 0.6, 0.6, 0.6 }, at = { 1.4, 4.2, 1.0 }, color = "glass" },
		-- three barrels from (x, 3.9, -1.2) up 40 degrees, 2.6 long
		{ name = "gunL", parent = "turret", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 2.6 }, at = { -0.9, 4.74, -2.2 }, rot = { 40, 0, 0 }, color = "metal" },
		{ name = "gunC", parent = "turret", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 2.6 }, at = { 0, 4.74, -2.2 }, rot = { 40, 0, 0 }, color = "metal" },
		{ name = "gunR", parent = "turret", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 2.6 }, at = { 0.9, 4.74, -2.2 }, rot = { 40, 0, 0 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "turret", at = { -0.9, 5.57, -3.19 } },
		{ name = "muzzle2", parent = "turret", at = { 0, 5.57, -3.19 } },
		{ name = "muzzle3", parent = "turret", at = { 0.9, 5.57, -3.19 } },
	},
}
