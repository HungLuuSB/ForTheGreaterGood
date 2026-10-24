--!strict
-- Twin Guard (Chaos twin laser tower, T1, footprint 2; S-157): the Guard's
-- round pad and post under a wider rounded `turret` with two Guard laser
-- tubes welded either side, firing in turn. Each tube is its own client
-- piece (`barrel1` left, `barrel2` right) so it recoils alone; `muzzle1` /
-- `muzzle2` at their lenses. Model space, forward = -Z.

return {
	id = "chs_twin_guard",
	visualPieces = { "barrel1", "barrel2" },
	parts = {
		{ name = "base", shape = "cylinder", axis = "y", size = { 11.6, 1.0, 11.6 }, at = { 0, 0.5, 0 }, color = "dark" },
		{ name = "patch", parent = "base", shape = "box", size = { 3.2, 0.06, 2.4 }, at = { 2.6, 1.03, 2.4 }, color = "metal" },
		{ name = "teamA", parent = "base", shape = "box", size = { 2.6, 0.08, 2.0 }, at = { -2.8, 1.04, 2.2 }, color = "team" },
		{ name = "eraA", parent = "base", shape = "box", size = { 2.4, 1.0, 0.5 }, at = { 0, 1.4, -4.5 }, color = "metal" },
		{ name = "eraB", parent = "base", shape = "box", size = { 2.2, 1.0, 0.5 }, at = { -3.5, 1.4, -2.9 }, rot = { 0, 50, 0 }, color = "metal" },
		{ name = "eraC", parent = "base", shape = "box", size = { 2.2, 1.0, 0.5 }, at = { 3.5, 1.4, -2.9 }, rot = { 0, -50, 0 }, color = "metal" },
		{ name = "drumTank", parent = "base", shape = "cylinder", axis = "y", size = { 1.4, 1.8, 1.4 }, at = { -3.6, 1.9, 3.0 }, color = "metal" },
		{ name = "post", parent = "base", shape = "cylinder", axis = "y", size = { 3.2, 2.4, 3.2 }, at = { 0, 2.2, 0 }, color = "hull" },

		{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 5.0, 1.9, 5.0 }, at = { 0, 4.35, 0.2 }, pivot = { 0, 3.4, 0 }, color = "hull" },
		{ name = "roofTeam", parent = "turret", shape = "box", size = { 2.8, 0.08, 2.2 }, at = { 0, 5.34, 0.5 }, color = "team" },
		{ name = "sensor", parent = "turret", shape = "box", size = { 0.6, 0.4, 0.4 }, at = { 0, 5.0, -2.1 }, color = "glass" },

		{ name = "barrel1", parent = "turret", shape = "cylinder", axis = "z", size = { 1.0, 1.0, 3.2 }, at = { -1.7, 4.3, -3.2 }, pivot = { -1.7, 4.3, -1.6 }, color = "metal" },
		{ name = "brace1", parent = "barrel1", shape = "box", size = { 0.3, 0.9, 2.0 }, at = { -2.35, 4.3, -2.6 }, color = "dark" },
		{ name = "lens1", parent = "barrel1", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 0.2 }, at = { -1.7, 4.3, -4.85 }, color = "glass" },
		{ name = "barrel2", parent = "turret", shape = "cylinder", axis = "z", size = { 1.0, 1.0, 3.2 }, at = { 1.7, 4.3, -3.2 }, pivot = { 1.7, 4.3, -1.6 }, color = "metal" },
		{ name = "brace2", parent = "barrel2", shape = "box", size = { 0.3, 0.9, 2.0 }, at = { 2.35, 4.3, -2.6 }, color = "dark" },
		{ name = "lens2", parent = "barrel2", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 0.2 }, at = { 1.7, 4.3, -4.85 }, color = "glass" },
	},
	attachments = {
		{ name = "muzzle1", parent = "barrel1", at = { -1.7, 4.3, -5.0 } },
		{ name = "muzzle2", parent = "barrel2", at = { 1.7, 4.3, -5.0 } },
	},
}
