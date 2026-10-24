--!strict
-- Beamer (Order beam tower, T1, footprint 2; S-157): an armored slab and a
-- tall pedestal under a yoke `turret` with two cheeks; between them the
-- `barrel` (pitch) is a fat focusing emitter: a drum housing, coil rings and
-- a wide blue lens dish at the front, `muzzle` at the lens (the beam's
-- start). Model space, forward = -Z.

return {
	id = "ord_beamer",
	parts = {
		{ name = "base", shape = "box", size = { 11, 1.2, 11 }, at = { 0, 0.6, 0 }, color = "hull" },
		{ name = "slopeF", parent = "base", shape = "wedge", size = { 11, 1.2, 1.2 }, at = { 0, 0.6, -6.1 }, color = "hull" },
		{ name = "slopeB", parent = "base", shape = "wedge", size = { 11, 1.2, 1.2 }, at = { 0, 0.6, 6.1 }, rot = { 0, 180, 0 }, color = "hull" },
		{ name = "teamA", parent = "base", shape = "box", size = { 3.4, 0.08, 1.4 }, at = { 0, 1.24, 4.4 }, color = "team" },
		{ name = "capacitorL", parent = "base", shape = "box", size = { 1.6, 1.6, 2.4 }, at = { -3.8, 2.0, 2.6 }, color = "metal" },
		{ name = "capacitorR", parent = "base", shape = "box", size = { 1.6, 1.6, 2.4 }, at = { 3.8, 2.0, 2.6 }, color = "metal" },
		{ name = "pedestal", parent = "base", shape = "cylinder", axis = "y", size = { 3.2, 2.6, 3.2 }, at = { 0, 2.5, 0 }, color = "dark" },

		{ name = "turret", parent = "base", shape = "box", size = { 3.6, 1.0, 3.2 }, at = { 0, 4.3, 0.2 }, pivot = { 0, 3.8, 0 }, color = "hull" },
		{ name = "cheekL", parent = "turret", shape = "box", size = { 0.6, 2.6, 2.6 }, at = { -1.9, 5.9, 0 }, color = "hull" },
		{ name = "cheekR", parent = "turret", shape = "box", size = { 0.6, 2.6, 2.6 }, at = { 1.9, 5.9, 0 }, color = "hull" },
		{ name = "cheekTeam", parent = "turret", shape = "box", size = { 0.08, 1.2, 1.6 }, at = { -2.24, 6.0, 0.2 }, color = "team" },

		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 2.6, 2.6, 3.2 }, at = { 0, 6.0, -0.6 }, pivot = { 0, 6.0, 0 }, color = "metal" },
		{ name = "coil1", parent = "barrel", shape = "cylinder", axis = "z", size = { 2.9, 2.9, 0.3 }, at = { 0, 6.0, -1.2 }, color = "dark" },
		{ name = "coil2", parent = "barrel", shape = "cylinder", axis = "z", size = { 2.9, 2.9, 0.3 }, at = { 0, 6.0, 0.4 }, color = "dark" },
		{ name = "dish", parent = "barrel", shape = "cylinder", axis = "z", size = { 3.2, 3.2, 0.4 }, at = { 0, 6.0, -2.4 }, color = "hull" },
		{ name = "lens", parent = "barrel", shape = "cylinder", axis = "z", size = { 2.0, 2.0, 0.2 }, at = { 0, 6.0, -2.66 }, color = "glass" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 6.0, -2.8 } },
	},
}
