--!strict
-- Locust (Chaos swarm tank, T1, proposed footprint 1; docs/design/factions.md):
-- a very small, cheap tracked tank, narrow and high off the ground, with a
-- little turret and a long autocannon. Reads smaller and lighter than the
-- Ravager. Model space, forward = -Z.

return {
	id = "chs_locust",
	parts = {
		{ name = "base", shape = "box", size = { 3.4, 0.9, 4.8 }, at = { 0, 1.35, 0.3 }, color = "hull" },
		{ name = "nose", parent = "base", shape = "wedge", size = { 3.4, 0.9, 1.2 }, at = { 0, 1.35, -2.7 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 0.9, 1.1, 5.6 }, at = { -2.15, 0.55, -0.1 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "trackR", parent = "base", shape = "box", size = { 0.9, 1.1, 5.6 }, at = { 2.15, 0.55, -0.1 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "eraL", parent = "base", shape = "box", size = { 0.2, 0.5, 1.4 }, at = { -1.8, 1.4, -1.4 }, color = "metal" },
		{ name = "eraR", parent = "base", shape = "box", size = { 0.2, 0.5, 1.4 }, at = { 1.8, 1.4, -1.4 }, color = "metal" },
		{ name = "light", parent = "base", shape = "box", size = { 1.4, 0.12, 0.08 }, at = { 0, 1.3, -3.32 }, color = "glass" },

		{ name = "turret", parent = "base", shape = "box", size = { 2, 0.8, 2.1 }, at = { 0, 2.2, 0.7 }, color = "hull" },
		{ name = "roofTeam", parent = "turret", shape = "box", size = { 1.5, 0.08, 1.5 }, at = { 0, 2.64, 0.8 }, color = "team" },
		{ name = "sensor", parent = "turret", shape = "box", size = { 0.5, 0.25, 0.1 }, at = { 0.55, 2.4, -0.39 }, color = "glass" },

		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 3.2 }, at = { 0, 2.2, -1.9 }, pivot = { 0, 2.2, -0.3 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 2.2, -3.5 } },
	},
}
