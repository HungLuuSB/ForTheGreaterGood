--!strict
-- Sovereign (Order command vehicle, footprint 1): the unit a player must keep
-- alive, so it reads unique at any zoom: a broad armored hull behind deep
-- skirts, a raised command tower with a wraparound glass band and a crown of
-- antennas, a big team plate on the deck, and on the `nano` turntable at the
-- back a heavy boom with a large glowing emitter. Order reads heavy (M-14).
-- Model space, forward = -Z.

return {
	id = "ord_sovereign",
	parts = {
		{ name = "base", shape = "box", size = { 6.0, 1.5, 7.2 }, at = { 0, 1.55, 0.2 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 6.0, 1.5, 1.2 }, at = { 0, 1.55, -4.0 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.2, 1.3, 8.2 }, at = { -2.9, 0.65, 0 }, color = "track" },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.2, 1.3, 8.2 }, at = { 2.9, 0.65, 0 }, color = "track" },
		{ name = "skirtL", parent = "base", shape = "box", size = { 0.45, 1.3, 7.8 }, at = { -3.65, 1.2, 0 }, color = "hull" },
		{ name = "skirtR", parent = "base", shape = "box", size = { 0.45, 1.3, 7.8 }, at = { 3.65, 1.2, 0 }, color = "hull" },
		{ name = "deckTeam", parent = "base", shape = "box", size = { 4.8, 0.08, 2.4 }, at = { 0, 2.34, -2.2 }, color = "team" },

		{ name = "tower", parent = "base", shape = "box", size = { 3.6, 2.0, 2.8 }, at = { 0, 3.3, 0.2 }, color = "hull" },
		{ name = "towerGlass", parent = "base", shape = "box", size = { 3.7, 0.35, 2.9 }, at = { 0, 3.8, 0.2 }, color = "glass" },
		{ name = "towerRoof", parent = "base", shape = "box", size = { 4.0, 0.3, 3.2 }, at = { 0, 4.45, 0.2 }, color = "dark" },
		{ name = "roofTeam", parent = "base", shape = "box", size = { 2.6, 0.08, 1.8 }, at = { 0, 4.64, 0.2 }, color = "team" },
		{ name = "antenna1", parent = "base", shape = "box", size = { 0.12, 2.6, 0.12 }, at = { -1.6, 5.9, 1.4 }, color = "dark" },
		{ name = "antenna2", parent = "base", shape = "box", size = { 0.12, 2.0, 0.12 }, at = { 1.6, 5.6, 1.4 }, color = "dark" },
		{ name = "antenna3", parent = "base", shape = "box", size = { 0.12, 1.6, 0.12 }, at = { 1.6, 5.4, -1.0 }, color = "dark" },
		{ name = "commandLight", parent = "base", shape = "ball", size = { 0.5, 0.5, 0.5 }, at = { -1.6, 7.3, 1.4 }, color = "glass" },

		{ name = "nano", parent = "base", shape = "cylinder", axis = "y", size = { 2.6, 0.5, 2.6 }, at = { 0, 2.55, 2.6 }, color = "hull" },
		{ name = "boom", parent = "nano", shape = "box", size = { 0.9, 0.9, 3.6 }, at = { 0, 3.6, 3.4 }, rot = { -35, 0, 0 }, color = "hull" },
		{ name = "emitter", parent = "nano", shape = "ball", size = { 1.4, 1.4, 1.4 }, at = { 0, 4.8, 4.3 }, color = "glass" },
	},
}
