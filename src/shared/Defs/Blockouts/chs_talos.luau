--!strict
-- Talos (Chaos lobbing gun, T1, footprint 2; S-157): a sandbagged round pad
-- with welded plates, a rugged rounded `turret` with a crude slab shield,
-- and a short, fat mortar-howitzer `barrel` (pitch; up to 85 degrees for
-- high-arc shells) with a banded muzzle. Modelled level; `muzzle` at the
-- mouth. Model space, forward = -Z.

return {
	id = "chs_talos",
	parts = {
		{ name = "base", shape = "cylinder", axis = "y", size = { 11.6, 1.0, 11.6 }, at = { 0, 0.5, 0 }, color = "dark" },
		{ name = "bagsF", parent = "base", shape = "box", size = { 6, 1.0, 1.2 }, at = { 0, 1.5, -4.4 }, color = "track" },
		{ name = "bagsL", parent = "base", shape = "box", size = { 1.2, 1.0, 4 }, at = { -4.4, 1.5, -1.6 }, rot = { 0, 20, 0 }, color = "track" },
		{ name = "bagsR", parent = "base", shape = "box", size = { 1.2, 1.0, 4 }, at = { 4.4, 1.5, -1.6 }, rot = { 0, -20, 0 }, color = "track" },
		{ name = "teamA", parent = "base", shape = "box", size = { 2.8, 0.08, 2.0 }, at = { 0, 1.04, 3.8 }, color = "team" },
		{ name = "shells", parent = "base", shape = "cylinder", axis = "y", size = { 1.4, 1.4, 1.4 }, at = { 3.6, 1.7, 3.2 }, color = "metal" },
		{ name = "post", parent = "base", shape = "cylinder", axis = "y", size = { 3.6, 1.4, 3.6 }, at = { 0, 1.7, 0.2 }, color = "hull" },

		{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 5.0, 1.8, 5.0 }, at = { 0, 3.3, 0.4 }, pivot = { 0, 2.4, 0.2 }, color = "hull" },
		{ name = "slab", parent = "turret", shape = "box", size = { 4.6, 2.2, 0.5 }, at = { 0, 4.6, -1.6 }, rot = { -12, 0, 0 }, color = "metal" },
		{ name = "roofTeam", parent = "turret", shape = "box", size = { 2.6, 0.08, 2.0 }, at = { 0, 4.24, 1.4 }, color = "team" },
		{ name = "sensor", parent = "turret", shape = "box", size = { 0.6, 0.4, 0.4 }, at = { -1.8, 4.5, -0.6 }, color = "glass" },

		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 1.8, 1.8, 4.2 }, at = { 0, 4.4, -2.4 }, pivot = { 0, 4.4, 0 }, color = "metal" },
		{ name = "band1", parent = "barrel", shape = "cylinder", axis = "z", size = { 2.1, 2.1, 0.4 }, at = { 0, 4.4, -1.4 }, color = "dark" },
		{ name = "band2", parent = "barrel", shape = "cylinder", axis = "z", size = { 2.2, 2.2, 0.5 }, at = { 0, 4.4, -4.3 }, color = "dark" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 4.4, -4.6 } },
	},
}
