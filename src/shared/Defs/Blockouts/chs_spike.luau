--!strict
-- Spike (Chaos gun turret, T1, footprint 1): a lighter open base with
-- reactive-armor blocks, a compact rounded turret with twin guns and an
-- orange sensor, team plate on the roof. Model space, forward = -Z
-- (docs/contracts/rig.md).

return {
	id = "chs_spike",
	parts = {
		{ name = "base", shape = "cylinder", axis = "y", size = { 5.6, 1.2, 5.6 }, at = { 0, 0.6, 0 }, color = "dark" },
		{ name = "eraA", parent = "base", shape = "box", size = { 1.6, 0.9, 0.3 }, at = { 0, 0.9, -2.85 }, color = "metal" },
		{ name = "eraB", parent = "base", shape = "box", size = { 1.6, 0.9, 0.3 }, at = { -2.2, 0.9, -1.8 }, rot = { 0, 50, 0 }, color = "metal" },
		{ name = "eraC", parent = "base", shape = "box", size = { 1.6, 0.9, 0.3 }, at = { 2.2, 0.9, -1.8 }, rot = { 0, -50, 0 }, color = "metal" },
		{ name = "post", parent = "base", shape = "cylinder", axis = "y", size = { 2, 1.2, 2 }, at = { 0, 1.8, 0 }, color = "hull" },

		{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 3.4, 1.4, 3.4 }, at = { 0, 3.0, 0.2 }, pivot = { 0, 2.4, 0 }, color = "hull" },
		{ name = "roofTeam", parent = "turret", shape = "box", size = { 2.2, 0.08, 1.8 }, at = { 0, 3.74, 0.4 }, color = "team" },
		{ name = "sensor", parent = "turret", shape = "box", size = { 0.5, 0.3, 0.3 }, at = { -1.1, 3.4, -1.45 }, color = "glass" },
		{ name = "gunL", parent = "turret", shape = "cylinder", axis = "z", size = { 0.4, 0.4, 3.8 }, at = { -0.45, 3.0, -3.2 }, color = "metal" },
		{ name = "gunR", parent = "turret", shape = "cylinder", axis = "z", size = { 0.4, 0.4, 3.8 }, at = { 0.45, 3.0, -3.2 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "turret", at = { 0, 3.0, -5.1 } },
	},
}
