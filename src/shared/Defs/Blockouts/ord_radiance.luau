--!strict
-- Radiance (Order beam tower, T2, footprint 2; S-96, client request 2 /
-- sim request 43, BAR-Pulsar style): an armored drum with glowing charge
-- rails, an armored `shell` collar round the pit in its top, and in the pit
-- the `turret`, a tall armored column with a heavy head carrying the long
-- emitter `barrel`. Switched off it retracts: the turret sinks into the
-- drum, the emitter folds down, and two armored lids (client-only `shellL` /
-- `shellR`, hinged on the collar) close over the pit (pose `retracted`,
-- Pending/Registry). Model space, forward = -Z.

-- footprint 2 -> 3 (size scale, M-26 / S-104): scaled until the redesign lands
return require("./Scale").scaled({
	id = "ord_radiance",
	visualPieces = { "shellL", "shellR" },
	parts = {
		{ name = "base", shape = "box", size = { 12, 4, 12 }, at = { 0, 2, 0 }, color = "hull" },
		{ name = "wallF", parent = "base", shape = "wedge", size = { 12, 4, 1.4 }, at = { 0, 2, -6.7 }, color = "hull" },
		{ name = "wallB", parent = "base", shape = "wedge", size = { 12, 4, 1.4 }, at = { 0, 2, 6.7 }, rot = { 0, 180, 0 }, color = "hull" },
		{ name = "wallL", parent = "base", shape = "wedge", size = { 12, 4, 1.4 }, at = { -6.7, 2, 0 }, rot = { 0, 90, 0 }, color = "hull" },
		{ name = "wallR", parent = "base", shape = "wedge", size = { 12, 4, 1.4 }, at = { 6.7, 2, 0 }, rot = { 0, -90, 0 }, color = "hull" },
		{ name = "pit", parent = "base", shape = "box", size = { 6.4, 0.1, 6.4 }, at = { 0, 4.02, 0 }, color = "dark" },
		{ name = "teamF", parent = "base", shape = "box", size = { 4, 0.08, 1.2 }, at = { 0, 4.04, -5.1 }, color = "team" },
		{ name = "teamB", parent = "base", shape = "box", size = { 4, 0.08, 1.2 }, at = { 0, 4.04, 5.1 }, color = "team" },
		-- charge rails (power glow): four strips down the drum's corners
		{ name = "railFL", parent = "base", shape = "box", size = { 0.3, 3.2, 0.3 }, at = { -5.9, 2.2, -5.9 }, color = "glass" },
		{ name = "railFR", parent = "base", shape = "box", size = { 0.3, 3.2, 0.3 }, at = { 5.9, 2.2, -5.9 }, color = "glass" },
		{ name = "railBL", parent = "base", shape = "box", size = { 0.3, 3.2, 0.3 }, at = { -5.9, 2.2, 5.9 }, color = "glass" },
		{ name = "railBR", parent = "base", shape = "box", size = { 0.3, 3.2, 0.3 }, at = { 5.9, 2.2, 5.9 }, color = "glass" },

		-- the armored collar round the pit (the def's `shell`; it doesn't move)
		{ name = "shell", parent = "base", shape = "box", size = { 8.4, 0.8, 1 }, at = { 0, 4.4, -3.7 }, pivot = { 0, 4, 0 }, color = "hull" },
		{ name = "collarB", parent = "shell", shape = "box", size = { 8.4, 0.8, 1 }, at = { 0, 4.4, 3.7 }, color = "hull" },
		{ name = "collarL", parent = "shell", shape = "box", size = { 1, 0.8, 6.4 }, at = { -3.7, 4.4, 0 }, color = "hull" },
		{ name = "collarR", parent = "shell", shape = "box", size = { 1, 0.8, 6.4 }, at = { 3.7, 4.4, 0 }, color = "hull" },

		-- the turret: a tall column and a head; pivot at the pit floor
		{ name = "turret", parent = "base", shape = "box", size = { 2.6, 6, 2.6 }, at = { 0, 7, 0 }, pivot = { 0, 4, 0 }, color = "hull" },
		{ name = "head", parent = "turret", shape = "box", size = { 3.6, 1.6, 3.2 }, at = { 0, 10.8, 0.2 }, color = "hull" },
		{ name = "headTeam", parent = "turret", shape = "box", size = { 2.4, 0.08, 2.0 }, at = { 0, 11.64, 0.4 }, color = "team" },
		{ name = "coreLight", parent = "turret", shape = "box", size = { 2.7, 0.3, 2.7 }, at = { 0, 9.6, 0 }, color = "glass" },

		-- the emitter: a long barrel from the head's front, pitch pivot at the head
		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 5.6 }, at = { 0, 10.8, -4.0 }, pivot = { 0, 10.8, -1.2 }, color = "metal" },
		{ name = "lens", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.2, 1.2, 0.3 }, at = { 0, 10.8, -6.9 }, color = "glass" },

		-- lids: hinged on the collar's side edges, standing open; the
		-- retracted pose swings them flat over the pit
		{ name = "shellL", parent = "shell", shape = "box", size = { 0.4, 3.2, 6.4 }, at = { -3.4, 6.4, 0 }, pivot = { -3.4, 4.8, 0 }, color = "hull" },
		{ name = "shellR", parent = "shell", shape = "box", size = { 0.4, 3.2, 6.4 }, at = { 3.4, 6.4, 0 }, pivot = { 3.4, 4.8, 0 }, color = "hull" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 10.8, -7.1 } },
	},
}, 1.5)
