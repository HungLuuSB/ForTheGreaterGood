--!strict
-- Basilisk (Chaos beam tower, T2 defense, proposed footprint 2; client request
-- 2 / sim request 43, BAR-Pulsar style): a lower, open-framed drum with
-- glowing charge coils, and in its pit the `turret`, a thinner lattice column
-- with a single big "eye" lens head and a shorter emitter `barrel` (the
-- basilisk's gaze). Switched off it retracts like Order's Lucent: turret
-- down, emitter folded, crude shell plates (client-only `shellL` / `shellR`)
-- slammed over the pit (pose `retracted`). Model space, forward = -Z.

return {
	id = "chs_basilisk",
	visualPieces = { "shellL", "shellR" },
	parts = {
		{ name = "base", shape = "box", size = { 13, 3, 13 }, at = { 0, 1.5, 0 }, color = "dark" },
		{ name = "pit", parent = "base", shape = "box", size = { 6, 0.1, 6 }, at = { 0, 3.02, 0 }, color = "dark" },
		{ name = "team", parent = "base", shape = "box", size = { 3.6, 0.08, 1.6 }, at = { 0, 3.04, 4.6 }, color = "team" },
		{ name = "coilF", parent = "base", shape = "cylinder", axis = "x", size = { 9, 0.8, 0.8 }, at = { 0, 2.4, -6.1 }, color = "glass" },
		{ name = "coilB", parent = "base", shape = "cylinder", axis = "x", size = { 9, 0.8, 0.8 }, at = { 0, 2.4, 6.1 }, color = "glass" },
		{ name = "tankL", parent = "base", shape = "cylinder", axis = "y", size = { 2.2, 2.6, 2.2 }, at = { -5.2, 4.3, 4.6 }, color = "metal" },

		{ name = "turret", parent = "base", shape = "box", size = { 1.6, 6, 1.6 }, at = { 0, 6, 0 }, pivot = { 0, 3, 0 }, color = "hull" },
		{ name = "head", parent = "turret", shape = "box", size = { 3.0, 1.8, 2.6 }, at = { 0, 9.6, 0.2 }, color = "hull" },
		{ name = "eye", parent = "turret", shape = "ball", size = { 1.4, 1.4, 1.4 }, at = { 0, 9.6, -1.2 }, color = "glass" },
		{ name = "headTeam", parent = "turret", shape = "box", size = { 2.0, 0.08, 1.6 }, at = { 0, 10.54, 0.4 }, color = "team" },

		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 4.0 }, at = { 0, 9.6, -3.4 }, pivot = { 0, 9.6, -1.4 }, color = "metal" },

		{ name = "shellL", parent = "base", shape = "box", size = { 0.5, 3.0, 6 }, at = { -3.2, 4.5, 0 }, pivot = { -3.2, 3, 0 }, color = "metal" },
		{ name = "shellR", parent = "base", shape = "box", size = { 0.5, 3.0, 6 }, at = { 3.2, 4.5, 0 }, pivot = { 3.2, 3, 0 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 9.6, -5.5 } },
	},
}
