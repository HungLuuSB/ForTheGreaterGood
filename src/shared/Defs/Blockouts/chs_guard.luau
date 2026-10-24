--!strict
-- Guard (Chaos laser tower, T1, footprint 2; S-157): a round patched pad
-- with reactive-armor blocks, a squat post, a rounded `turret` with one
-- stubby red laser tube braced on the side and an orange sensor. The def
-- turns `turret`; `muzzle` at the lens. Rugged and improvised (M-14).
-- Model space, forward = -Z.

return {
	id = "chs_guard",
	parts = {
		{ name = "base", shape = "cylinder", axis = "y", size = { 11.4, 1.0, 11.4 }, at = { 0, 0.5, 0 }, color = "dark" },
		{ name = "patch", parent = "base", shape = "box", size = { 3.2, 0.06, 2.4 }, at = { -2.6, 1.03, 2.4 }, color = "metal" },
		{ name = "teamA", parent = "base", shape = "box", size = { 2.6, 0.08, 2.0 }, at = { 2.8, 1.04, 2.2 }, color = "team" },
		{ name = "eraA", parent = "base", shape = "box", size = { 2.2, 1.0, 0.5 }, at = { 0, 1.4, -4.4 }, color = "metal" },
		{ name = "eraB", parent = "base", shape = "box", size = { 2.2, 1.0, 0.5 }, at = { -3.4, 1.4, -2.8 }, rot = { 0, 50, 0 }, color = "metal" },
		{ name = "eraC", parent = "base", shape = "box", size = { 2.2, 1.0, 0.5 }, at = { 3.4, 1.4, -2.8 }, rot = { 0, -50, 0 }, color = "metal" },
		{ name = "post", parent = "base", shape = "cylinder", axis = "y", size = { 3.0, 2.4, 3.0 }, at = { 0, 2.2, 0 }, color = "hull" },

		{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 4.2, 1.8, 4.2 }, at = { 0, 4.3, 0.2 }, pivot = { 0, 3.4, 0 }, color = "hull" },
		{ name = "roofTeam", parent = "turret", shape = "box", size = { 2.4, 0.08, 2.0 }, at = { 0, 5.24, 0.5 }, color = "team" },
		{ name = "sensor", parent = "turret", shape = "box", size = { 0.6, 0.4, 0.4 }, at = { -1.4, 4.9, -1.6 }, color = "glass" },
		{ name = "tube", parent = "turret", shape = "cylinder", axis = "z", size = { 1.0, 1.0, 3.0 }, at = { 0.3, 4.3, -2.9 }, color = "metal" },
		{ name = "brace", parent = "turret", shape = "box", size = { 0.3, 0.9, 2.2 }, at = { 1.0, 4.3, -2.4 }, color = "dark" },
		{ name = "lens", parent = "turret", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 0.2 }, at = { 0.3, 4.3, -4.45 }, color = "glass" },
	},
	attachments = {
		{ name = "muzzle", parent = "turret", at = { 0.3, 4.3, -4.6 } },
	},
}
