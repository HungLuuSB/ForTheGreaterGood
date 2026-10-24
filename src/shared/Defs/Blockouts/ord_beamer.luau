--!strict
-- Beamer (Order beam tower, T1, footprint 2; S-157; the user's reference
-- 2026-10-24: a tall beam tower with an arched frame): a heavy octagonal
-- footing with capacitor drums, a tall column braced by two arched conduit
-- pipes, and on top the `turret`, a long boxy housing with a lit top, whose
-- `barrel` (pitch) is a focusing emitter with coil rings and a blue lens;
-- `muzzle` at the lens (the beam's start). Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "cylinder", axis = "y", size = { 8.0, 1.2, 8.0 }, at = { 0, 0.6, 0 }, color = "dark" },
	{ name = "footing", parent = "base", shape = "box", size = { 5.6, 4.0, 5.6 }, at = { 0, 3.2, 0 }, color = "hull" },
	{ name = "footTeamL", parent = "base", shape = "box", size = { 0.08, 2.8, 2.6 }, at = { -2.84, 3.2, 0 }, color = "team" },
	{ name = "footTeamR", parent = "base", shape = "box", size = { 0.08, 2.8, 2.6 }, at = { 2.84, 3.2, 0 }, color = "team" },
	{ name = "capL", parent = "base", shape = "cylinder", axis = "z", size = { 1.2, 1.2, 1.0 }, at = { -1.5, 2.2, -3.0 }, color = "metal" },
	{ name = "capR", parent = "base", shape = "cylinder", axis = "z", size = { 1.2, 1.2, 1.0 }, at = { 1.5, 2.2, -3.0 }, color = "metal" },
	{ name = "column", parent = "base", shape = "box", size = { 2.4, 7.4, 2.0 }, at = { 0, 8.9, 0.4 }, color = "hull" },
	{ name = "columnTeam", parent = "base", shape = "box", size = { 1.2, 5.6, 0.08 }, at = { 0, 9.0, -0.64 }, color = "team" },
	{ name = "pipeL", parent = "base", shape = "cylinder", axis = "y", size = { 0.6, 7.6, 0.6 }, at = { -2.0, 9.0, 1.4 }, color = "metal" },
	{ name = "pipeR", parent = "base", shape = "cylinder", axis = "y", size = { 0.6, 7.6, 0.6 }, at = { 2.0, 9.0, 1.4 }, color = "metal" },
	{ name = "arch", parent = "base", shape = "cylinder", axis = "x", size = { 4.6, 0.6, 0.6 }, at = { 0, 12.8, 1.4 }, color = "metal" },

	{ name = "turret", parent = "base", shape = "box", size = { 2.6, 2.0, 4.6 }, at = { 0, 13.9, 0.4 }, pivot = { 0, 12.8, 0 }, color = "hull" },
	{ name = "lights", parent = "turret", shape = "box", size = { 1.6, 0.1, 3.4 }, at = { 0, 14.92, 0.6 }, color = "glass" },
	{ name = "turretTeam", parent = "turret", shape = "box", size = { 0.08, 1.2, 2.4 }, at = { -1.34, 13.9, 0.6 }, color = "team" },

	{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 1.2, 1.2, 3.4 }, at = { 0, 13.8, -3.4 }, pivot = { 0, 13.8, -1.8 }, color = "metal" },
	{ name = "coil1", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.7, 1.7, 0.3 }, at = { 0, 13.8, -2.4 }, color = "dark" },
	{ name = "coil2", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.7, 1.7, 0.3 }, at = { 0, 13.8, -3.6 }, color = "dark" },
	{ name = "lens", parent = "barrel", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 0.2 }, at = { 0, 13.8, -5.15 }, color = "glass" },
}

return {
	id = "ord_beamer",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 13.8, -5.3 } },
	},
}
