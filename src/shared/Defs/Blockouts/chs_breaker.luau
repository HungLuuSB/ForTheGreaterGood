--!strict
-- Breaker (Chaos coastal battery, T2, footprint 3): an open concrete-and-
-- frame gun platform with reactive blocks on its sea face, a rounded turret
-- with one very long gun and a twin missile box, orange lights.
-- Model space, forward = -Z.

return {
	id = "chs_breaker",
	parts = {
		{ name = "base", shape = "box", size = { 20, 2, 16 }, at = { 0, 1, 2 }, color = "dark" },
		{ name = "eraA", parent = "base", shape = "box", size = { 4, 1.4, 0.5 }, at = { -6, 1.2, -6.2 }, color = "metal" },
		{ name = "eraB", parent = "base", shape = "box", size = { 4, 1.4, 0.5 }, at = { 0, 1.2, -6.2 }, color = "metal" },
		{ name = "eraC", parent = "base", shape = "box", size = { 4, 1.4, 0.5 }, at = { 6, 1.2, -6.2 }, color = "metal" },
		{ name = "teamA", parent = "base", shape = "box", size = { 4, 0.1, 4 }, at = { -7, 2.05, 6 }, color = "team" },
		{ name = "rail", parent = "base", shape = "box", size = { 20, 0.3, 0.3 }, at = { 0, 3, 9.8 }, color = "dark" },
		{ name = "lightL", parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { -9.5, 2.4, -5.5 }, color = "glass" },
		{ name = "lightR", parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { 9.5, 2.4, -5.5 }, color = "glass" },

		{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 7, 2.6, 7 }, at = { 0, 3.3, 1 }, pivot = { 0, 2, 1 }, color = "hull" },
		{ name = "roofTeam", parent = "turret", shape = "box", size = { 4, 0.1, 3 }, at = { 0, 4.65, 2 }, color = "team" },
		{ name = "gun", parent = "turret", shape = "cylinder", axis = "z", size = { 1.2, 1.2, 13 }, at = { 0, 3.6, -8.5 }, color = "metal" },
		{ name = "missiles", parent = "turret", shape = "box", size = { 1.6, 1.4, 3 }, at = { 3.6, 4, -0.5 }, color = "dark" },
		{ name = "sensor", parent = "turret", shape = "box", size = { 0.8, 0.4, 0.1 }, at = { -2.2, 4, -2.45 }, color = "glass" },
	},
	attachments = {
		{ name = "muzzle", parent = "turret", at = { 0, 3.6, -15.1 } },
	},
}
