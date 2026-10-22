--!strict
-- Falcon (Order fighter, T1, footprint 1): a flat angular fuselage, swept
-- wings, canted twin tails in team color, twin engine glow; two precise
-- missiles on the `pylon` under the wing roots (the weapon turns it).
-- Model space, forward = -Z.

return {
	id = "ord_falcon",
	parts = {
		{ name = "base", shape = "box", size = { 1.6, 0.9, 7.4 }, at = { 0, 0.6, 0 }, color = "hull" },
		{ name = "nose", parent = "base", shape = "wedge", size = { 1.6, 0.9, 1.6 }, at = { 0, 0.6, -4.5 }, color = "hull" },
		{ name = "canopy", parent = "base", shape = "wedge", size = { 0.8, 0.45, 1.6 }, at = { 0, 1.25, -2.3 }, color = "glass" },
		{ name = "wingL", parent = "base", shape = "wedge", size = { 2.4, 0.2, 3.2 }, at = { -2, 0.45, 0.6 }, rot = { 0, -90, 0 }, color = "hull" },
		{ name = "wingR", parent = "base", shape = "wedge", size = { 2.4, 0.2, 3.2 }, at = { 2, 0.45, 0.6 }, rot = { 0, 90, 0 }, color = "hull" },
		{ name = "wingTeamL", parent = "base", shape = "box", size = { 1.2, 0.06, 1 }, at = { -2.2, 0.6, 1 }, color = "team" },
		{ name = "wingTeamR", parent = "base", shape = "box", size = { 1.2, 0.06, 1 }, at = { 2.2, 0.6, 1 }, color = "team" },
		{ name = "tailL", parent = "base", shape = "box", size = { 0.15, 1.3, 1.4 }, at = { -0.6, 1.55, 2.9 }, rot = { 0, 0, -15 }, color = "team" },
		{ name = "tailR", parent = "base", shape = "box", size = { 0.15, 1.3, 1.4 }, at = { 0.6, 1.55, 2.9 }, rot = { 0, 0, 15 }, color = "team" },
		{ name = "engineL", parent = "base", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 0.3 }, at = { -0.45, 0.6, 3.8 }, color = "glass" },
		{ name = "engineR", parent = "base", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 0.3 }, at = { 0.45, 0.6, 3.8 }, color = "glass" },
		{ name = "pylon", parent = "base", shape = "box", size = { 2.4, 0.3, 1.6 }, at = { 0, 0.05, 0.2 }, color = "dark" },
		{ name = "missileL", parent = "pylon", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 2 }, at = { -0.9, -0.15, -0.1 }, color = "metal" },
		{ name = "missileR", parent = "pylon", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 2 }, at = { 0.9, -0.15, -0.1 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "pylon", at = { 0, -0.15, -1.2 } },
	},
}
