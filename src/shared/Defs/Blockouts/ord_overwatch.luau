--!strict
-- Overwatch (Order twin laser tower, T1, footprint 2; S-157): a heavier
-- slab and plinth under a wide `turret` with two long green laser barrels
-- side by side that fire in turn. Each barrel is its own client piece
-- (`barrel1` left, `barrel2` right) so it recoils alone; `muzzle1` /
-- `muzzle2` at their lenses. Model space, forward = -Z.

return {
	id = "ord_overwatch",
	visualPieces = { "barrel1", "barrel2" },
	parts = {
		{ name = "base", shape = "box", size = { 12, 1.4, 12 }, at = { 0, 0.7, 0 }, color = "hull" },
		{ name = "slopeF", parent = "base", shape = "wedge", size = { 12, 1.4, 1.2 }, at = { 0, 0.7, -6.6 }, color = "hull" },
		{ name = "slopeB", parent = "base", shape = "wedge", size = { 12, 1.4, 1.2 }, at = { 0, 0.7, 6.6 }, rot = { 0, 180, 0 }, color = "hull" },
		{ name = "plinth", parent = "base", shape = "box", size = { 7, 1.4, 7 }, at = { 0, 2.1, 0 }, color = "hull" },
		{ name = "teamA", parent = "base", shape = "box", size = { 4, 0.08, 1.4 }, at = { 0, 1.44, 4.8 }, color = "team" },
		{ name = "hazard", parent = "base", shape = "box", size = { 7, 0.06, 0.5 }, at = { 0, 1.43, -5.0 }, color = "hazard" },
		{ name = "pedestal", parent = "base", shape = "cylinder", axis = "y", size = { 3.2, 1.2, 3.2 }, at = { 0, 3.4, 0 }, color = "dark" },

		{ name = "turret", parent = "base", shape = "box", size = { 4.8, 2.2, 4.2 }, at = { 0, 5.1, 0.4 }, pivot = { 0, 4.0, 0 }, color = "hull" },
		{ name = "turretTeam", parent = "turret", shape = "box", size = { 3.2, 0.08, 2.6 }, at = { 0, 6.24, 0.8 }, color = "team" },
		{ name = "sensor", parent = "turret", shape = "box", size = { 1.0, 0.5, 0.1 }, at = { 0, 5.7, -1.75 }, color = "glass" },
		{ name = "mantlet", parent = "turret", shape = "box", size = { 4.4, 1.4, 0.6 }, at = { 0, 4.9, -1.9 }, color = "dark" },

		{ name = "barrel1", parent = "turret", shape = "cylinder", axis = "z", size = { 0.8, 0.8, 4.6 }, at = { -1.3, 4.9, -4.3 }, pivot = { -1.3, 4.9, -2.0 }, color = "metal" },
		{ name = "rib1", parent = "barrel1", shape = "cylinder", axis = "z", size = { 1.1, 1.1, 0.3 }, at = { -1.3, 4.9, -3.6 }, color = "dark" },
		{ name = "lens1", parent = "barrel1", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 0.2 }, at = { -1.3, 4.9, -6.65 }, color = "glass" },
		{ name = "barrel2", parent = "turret", shape = "cylinder", axis = "z", size = { 0.8, 0.8, 4.6 }, at = { 1.3, 4.9, -4.3 }, pivot = { 1.3, 4.9, -2.0 }, color = "metal" },
		{ name = "rib2", parent = "barrel2", shape = "cylinder", axis = "z", size = { 1.1, 1.1, 0.3 }, at = { 1.3, 4.9, -3.6 }, color = "dark" },
		{ name = "lens2", parent = "barrel2", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 0.2 }, at = { 1.3, 4.9, -6.65 }, color = "glass" },
	},
	attachments = {
		{ name = "muzzle1", parent = "barrel1", at = { -1.3, 4.9, -6.8 } },
		{ name = "muzzle2", parent = "barrel2", at = { 1.3, 4.9, -6.8 } },
	},
}
