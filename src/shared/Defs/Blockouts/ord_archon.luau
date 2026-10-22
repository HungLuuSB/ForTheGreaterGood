--!strict
-- Archon (Order air superiority fighter, T2, footprint 1): longer than the
-- Falcon with broad stealth-shaped wings and canted tails, a chin sensor
-- `turret` (its radar missiles turn it), the missile `pylon` under the
-- wing roots. Model space, forward = -Z.

return {
	id = "ord_archon",
	parts = {
		{ name = "base", shape = "box", size = { 1.6, 0.9, 8.2 }, at = { 0, 0.6, 0 }, color = "hull" },
		{ name = "nose", parent = "base", shape = "wedge", size = { 1.6, 0.9, 1.6 }, at = { 0, 0.6, -4.9 }, color = "hull" },
		{ name = "canopy", parent = "base", shape = "wedge", size = { 0.8, 0.45, 1.6 }, at = { 0, 1.25, -2.7 }, color = "glass" },
		{ name = "wingL", parent = "base", shape = "wedge", size = { 2.6, 0.25, 4.6 }, at = { -2.1, 0.5, 0.4 }, rot = { 0, -90, 0 }, color = "hull" },
		{ name = "wingR", parent = "base", shape = "wedge", size = { 2.6, 0.25, 4.6 }, at = { 2.1, 0.5, 0.4 }, rot = { 0, 90, 0 }, color = "hull" },
		{ name = "wingTeamL", parent = "base", shape = "box", size = { 1.2, 0.06, 1 }, at = { -2.3, 0.6, 1 }, color = "team" },
		{ name = "wingTeamR", parent = "base", shape = "box", size = { 1.2, 0.06, 1 }, at = { 2.3, 0.6, 1 }, color = "team" },
		{ name = "tailL", parent = "base", shape = "box", size = { 0.15, 1.3, 1.4 }, at = { -0.6, 1.55, 3.3 }, rot = { 0, 0, -15 }, color = "team" },
		{ name = "tailR", parent = "base", shape = "box", size = { 0.15, 1.3, 1.4 }, at = { 0.6, 1.55, 3.3 }, rot = { 0, 0, 15 }, color = "team" },
		{ name = "engineL", parent = "base", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 0.3 }, at = { -0.45, 0.6, 4.2 }, color = "glass" },
		{ name = "engineR", parent = "base", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 0.3 }, at = { 0.45, 0.6, 4.2 }, color = "glass" },
		{ name = "pylon", parent = "base", shape = "box", size = { 2.4, 0.3, 1.6 }, at = { 0, 0.05, 0.2 }, color = "dark" },
		{ name = "missileL", parent = "pylon", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 2 }, at = { -0.9, -0.15, -0.1 }, color = "metal" },
		{ name = "missileR", parent = "pylon", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 2 }, at = { 0.9, -0.15, -0.1 }, color = "metal" },
		{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 0.8, 0.5, 0.8 }, at = { 0, 0, -3.2 }, color = "dark" },
		{ name = "sensor", parent = "turret", shape = "ball", size = { 0.4, 0.4, 0.4 }, at = { 0, -0.15, -3.5 }, color = "glass" },
	},
	attachments = {
		{ name = "muzzle", parent = "turret", at = { 0, -0.1, -3.8 } },
	},
}
