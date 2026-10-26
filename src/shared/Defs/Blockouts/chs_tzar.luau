--!strict
-- Tzar (Chaos heavy plasma tank, T2, footprint 2; S-181; the Fatboy's
-- counterpart): a long heavy hull on wide tracks with a steep glacis and
-- reactive blocks, exhaust stacks at the back, and a big cast `turret`
-- (turns) with a fat plasma cannon: glowing coils, a muzzle ring; `muzzle`
-- at the mouth. Chaos reads crude and brutal (M-14). Model space,
-- forward = -Z.

local CY = 4.3 -- the barrel's height

local parts = {
	{ name = "base", shape = "box", size = { 7.2, 2.2, 11 }, at = { 0, 2.0, 0.4 }, color = "hull" },
	{ name = "glacis", parent = "base", shape = "wedge", size = { 7.2, 2.2, 2.2 }, at = { 0, 2.0, -6.2 }, color = "hull" },
	{ name = "trackL", parent = "base", shape = "box", size = { 1.9, 2.2, 12.4 }, at = { -4.5, 1.1, 0 }, color = "track" },
	{ name = "trackR", parent = "base", shape = "box", size = { 1.9, 2.2, 12.4 }, at = { 4.5, 1.1, 0 }, color = "track" },
	{ name = "skirtL", parent = "base", shape = "box", size = { 0.3, 1.2, 10 }, at = { -5.55, 2.0, 0 }, color = "metal" },
	{ name = "skirtR", parent = "base", shape = "box", size = { 0.3, 1.2, 10 }, at = { 5.55, 2.0, 0 }, color = "metal" },
	{ name = "eraA", parent = "base", shape = "box", size = { 2.0, 0.6, 1.2 }, at = { -2.2, 3.15, -4.4 }, color = "metal" },
	{ name = "eraB", parent = "base", shape = "box", size = { 2.0, 0.6, 1.2 }, at = { 2.2, 3.15, -4.4 }, color = "metal" },
	{ name = "stackL", parent = "base", shape = "cylinder", axis = "y", size = { 0.8, 1.8, 0.8 }, at = { -2.4, 3.8, 5.0 }, color = "dark" },
	{ name = "stackR", parent = "base", shape = "cylinder", axis = "y", size = { 0.8, 1.8, 0.8 }, at = { 2.4, 3.8, 5.0 }, color = "dark" },
	{ name = "deckTeam", parent = "base", shape = "box", size = { 3, 0.1, 2 }, at = { 0, 3.15, 4.6 }, color = "team" },

	{ name = "turret", parent = "base", shape = "box", size = { 5.6, 2.0, 6.0 }, at = { 0, 4.1, 0.6 }, pivot = { 0, 3.1, 0.4 }, color = "hull" },
	{ name = "turretFront", parent = "turret", shape = "wedge", size = { 5.6, 2.0, 1.4 }, at = { 0, 4.1, -3.1 }, color = "hull" },
	{ name = "roofTeam", parent = "turret", shape = "box", size = { 3.4, 0.1, 3 }, at = { 0, 5.15, 1.2 }, color = "team" },
	{ name = "mantlet", parent = "turret", shape = "box", size = { 2.6, 1.8, 0.8 }, at = { 0, CY, -3.9 }, color = "dark" },
	{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 1.4, 1.4, 6.2 }, at = { 0, CY, -7.4 }, color = "metal" },
	{ name = "coil1", parent = "turret", shape = "cylinder", axis = "z", size = { 1.8, 1.8, 0.3 }, at = { 0, CY, -5.6 }, color = "glass" },
	{ name = "coil2", parent = "turret", shape = "cylinder", axis = "z", size = { 1.8, 1.8, 0.3 }, at = { 0, CY, -7.0 }, color = "glass" },
	{ name = "mouth", parent = "turret", shape = "cylinder", axis = "z", size = { 2.0, 2.0, 0.8 }, at = { 0, CY, -10.6 }, color = "dark" },
	{ name = "hatch", parent = "turret", shape = "cylinder", axis = "y", size = { 1.4, 0.4, 1.4 }, at = { 1.6, 5.3, 2.0 }, color = "dark" },
	{ name = "lamp", parent = "turret", shape = "box", size = { 0.5, 0.3, 0.1 }, at = { -2.0, 4.6, -2.45 }, color = "glass" },
}

return {
	id = "chs_tzar",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "turret", at = { 0, CY, -11.1 } },
	},
}
