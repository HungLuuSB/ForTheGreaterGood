--!strict
-- Beamer (Order beam tower, T1, footprint 2; S-157; the user's reference
-- 2026-10-24: a tall beam tower with an arched frame; F18 2026-10-26:
-- "turret should stand high, proud, tower above others", so taller and
-- heavier like its counterpart the Twin Guard, top ~19 studs): a heavy
-- octagonal footing with capacitor drums, a tall column braced by two arched
-- conduit pipes, and on top the `turret`, a long boxy housing with a lit
-- top, whose `barrel` (pitch) is a focusing emitter with coil rings and a
-- blue lens; `muzzle` at the lens (the beam's start). Model space,
-- forward = -Z.

local RING = 16.4 -- top of the column, where the housing turns
local EY = RING + 1.3 -- emitter height
local CH = RING - 6.4 -- column height, from the footing's top

local parts = {
	{ name = "base", shape = "cylinder", axis = "y", size = { 10.4, 1.2, 10.4 }, at = { 0, 0.6, 0 }, color = "dark" },
	{ name = "footing", parent = "base", shape = "box", size = { 7.2, 5.0, 7.2 }, at = { 0, 3.7, 0 }, color = "hull" },
	{ name = "footTeamL", parent = "base", shape = "box", size = { 0.08, 3.6, 3.4 }, at = { -3.64, 3.7, 0 }, color = "team" },
	{ name = "footTeamR", parent = "base", shape = "box", size = { 0.08, 3.6, 3.4 }, at = { 3.64, 3.7, 0 }, color = "team" },
	{ name = "capL", parent = "base", shape = "cylinder", axis = "z", size = { 1.6, 1.6, 1.2 }, at = { -1.9, 2.6, -3.9 }, color = "metal" },
	{ name = "capR", parent = "base", shape = "cylinder", axis = "z", size = { 1.6, 1.6, 1.2 }, at = { 1.9, 2.6, -3.9 }, color = "metal" },
	{ name = "column", parent = "base", shape = "box", size = { 3.0, CH, 2.6 }, at = { 0, 6.2 + CH / 2, 0.4 }, color = "hull" },
	{ name = "columnTeam", parent = "base", shape = "box", size = { 1.6, CH - 2, 0.08 }, at = { 0, 6.2 + CH / 2, -0.94 }, color = "team" },
	{ name = "pipeL", parent = "base", shape = "cylinder", axis = "y", size = { 0.8, CH + 0.4, 0.8 }, at = { -2.6, 6.2 + CH / 2, 1.8 }, color = "metal" },
	{ name = "pipeR", parent = "base", shape = "cylinder", axis = "y", size = { 0.8, CH + 0.4, 0.8 }, at = { 2.6, 6.2 + CH / 2, 1.8 }, color = "metal" },
	{ name = "arch", parent = "base", shape = "cylinder", axis = "x", size = { 6.0, 0.8, 0.8 }, at = { 0, RING, 1.8 }, color = "metal" },

	{ name = "turret", parent = "base", shape = "box", size = { 3.4, 2.6, 6.0 }, at = { 0, RING + 1.4, 0.4 }, pivot = { 0, RING, 0 }, color = "hull" },
	{ name = "lights", parent = "turret", shape = "box", size = { 2.2, 0.1, 4.4 }, at = { 0, RING + 2.72, 0.6 }, color = "glass" },
	{ name = "turretTeam", parent = "turret", shape = "box", size = { 0.08, 1.6, 3.2 }, at = { -1.74, RING + 1.4, 0.6 }, color = "team" },

	{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 1.6, 1.6, 4.4 }, at = { 0, EY, -4.6 }, pivot = { 0, EY, -2.6 }, color = "metal" },
	{ name = "coil1", parent = "barrel", shape = "cylinder", axis = "z", size = { 2.2, 2.2, 0.4 }, at = { 0, EY, -3.4 }, color = "dark" },
	{ name = "coil2", parent = "barrel", shape = "cylinder", axis = "z", size = { 2.2, 2.2, 0.4 }, at = { 0, EY, -5.0 }, color = "dark" },
	{ name = "lens", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.2, 1.2, 0.25 }, at = { 0, EY, -6.9 }, color = "glass" },
}

return {
	id = "ord_beamer",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, EY, -7.1 } },
	},
}
