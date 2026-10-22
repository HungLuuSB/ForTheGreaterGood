--!strict
-- Inferno (Chaos beam tower, T2, footprint 2; S-96, client request 2 / sim
-- request 43, BAR-Pulsar style): a lower, open-framed drum with glowing
-- charge coils, a crude armored `shell` collar round the pit, and in the pit
-- the `turret`, a thinner column with a single big "eye" lens head and a
-- shorter emitter `barrel`. Switched off it retracts like Order's Radiance:
-- turret down, emitter folded, crude lids (client-only `shellL` / `shellR`,
-- hinged on the collar) slammed over the pit (pose `retracted`). Model
-- space, forward = -Z.

-- footprint 2 -> 3 (size scale, M-26 / S-104): scaled until the redesign lands
return require("./Scale").scaled({
	id = "chs_inferno",
	visualPieces = { "shellL", "shellR" },
	parts = {
		{ name = "base", shape = "box", size = { 13, 3, 13 }, at = { 0, 1.5, 0 }, color = "dark" },
		{ name = "pit", parent = "base", shape = "box", size = { 6, 0.1, 6 }, at = { 0, 3.02, 0 }, color = "dark" },
		{ name = "team", parent = "base", shape = "box", size = { 3.6, 0.08, 1.4 }, at = { 0, 3.04, 5.3 }, color = "team" },
		{ name = "coilF", parent = "base", shape = "cylinder", axis = "x", size = { 9, 0.8, 0.8 }, at = { 0, 2.4, -6.1 }, color = "glass" },
		{ name = "coilB", parent = "base", shape = "cylinder", axis = "x", size = { 9, 0.8, 0.8 }, at = { 0, 2.4, 6.1 }, color = "glass" },
		{ name = "tankL", parent = "base", shape = "cylinder", axis = "y", size = { 2.2, 2.6, 2.2 }, at = { -5.2, 4.3, 4.6 }, color = "metal" },

		-- the crude collar round the pit (the def's `shell`; it doesn't move)
		{ name = "shell", parent = "base", shape = "box", size = { 8, 0.6, 1 }, at = { 0, 3.3, -3.5 }, pivot = { 0, 3, 0 }, color = "metal" },
		{ name = "collarB", parent = "shell", shape = "box", size = { 8, 0.6, 1 }, at = { 0, 3.3, 3.5 }, color = "metal" },
		{ name = "collarL", parent = "shell", shape = "box", size = { 1, 0.6, 6 }, at = { -3.5, 3.3, 0 }, color = "metal" },
		{ name = "collarR", parent = "shell", shape = "box", size = { 1, 0.6, 6 }, at = { 3.5, 3.3, 0 }, color = "metal" },

		{ name = "turret", parent = "base", shape = "box", size = { 1.6, 6, 1.6 }, at = { 0, 6, 0 }, pivot = { 0, 3, 0 }, color = "hull" },
		{ name = "head", parent = "turret", shape = "box", size = { 3.0, 1.8, 2.6 }, at = { 0, 9.6, 0.2 }, color = "hull" },
		{ name = "eye", parent = "turret", shape = "ball", size = { 1.4, 1.4, 1.4 }, at = { 0, 9.6, -1.2 }, color = "glass" },
		{ name = "headTeam", parent = "turret", shape = "box", size = { 2.0, 0.08, 1.6 }, at = { 0, 10.54, 0.4 }, color = "team" },

		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 4.0 }, at = { 0, 9.6, -3.4 }, pivot = { 0, 9.6, -1.4 }, color = "metal" },

		{ name = "shellL", parent = "shell", shape = "box", size = { 0.5, 3.0, 6 }, at = { -3.2, 5.1, 0 }, pivot = { -3.2, 3.6, 0 }, color = "metal" },
		{ name = "shellR", parent = "shell", shape = "box", size = { 0.5, 3.0, 6 }, at = { 3.2, 5.1, 0 }, pivot = { 3.2, 3.6, 0 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 9.6, -5.5 } },
	},
}, 1.5)
