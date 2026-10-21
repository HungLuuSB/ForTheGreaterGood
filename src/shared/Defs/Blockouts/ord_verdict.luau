--!strict
-- Verdict (Order self-propelled artillery): Lancer-family hull with a large
-- sloped turret set to the rear and a very long gun reaching well past the
-- nose. Model space, forward = -Z (docs/contracts/rig.md).

return {
	id = "ord_verdict",
	parts = {
		{ name = "base", shape = "box", size = { 5.0, 1.2, 7.4 }, at = { 0, 1.5, 0.2 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 5.0, 1.2, 1.4 }, at = { 0, 1.5, -4.2 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.1, 1.3, 8.4 }, at = { -2.65, 0.65, -0.2 }, color = "track" },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.1, 1.3, 8.4 }, at = { 2.65, 0.65, -0.2 }, color = "track" },
		{ name = "fenderL", parent = "base", shape = "box", size = { 1.3, 0.2, 8.0 }, at = { -2.65, 1.4, -0.2 }, color = "dark" },
		{ name = "fenderR", parent = "base", shape = "box", size = { 1.3, 0.2, 8.0 }, at = { 2.65, 1.4, -0.2 }, color = "dark" },

		{ name = "turret", parent = "base", shape = "box", size = { 4.0, 1.6, 3.6 }, at = { 0, 2.9, 1.6 }, color = "team" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 4.0, 1.6, 1.2 }, at = { 0, 2.9, -0.8 }, color = "team" },
		{ name = "bustle", parent = "turret", shape = "box", size = { 3.4, 1.0, 0.8 }, at = { 0, 2.8, 3.8 }, color = "dark" },
		{ name = "optic", parent = "turret", shape = "box", size = { 0.7, 0.5, 0.7 }, at = { 1.3, 3.95, 1.0 }, color = "glass" },
		{ name = "hatch", parent = "turret", shape = "cylinder", axis = "y", size = { 0.9, 0.2, 0.9 }, at = { -1.0, 3.8, 2.2 }, color = "dark" },

		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 9.0 }, at = { 0, 3.0, -5.6 }, pivot = { 0, 3.0, -1.1 }, color = "metal" },
		{ name = "mantlet", parent = "barrel", shape = "box", size = { 1.2, 1.0, 0.6 }, at = { 0, 3.0, -1.4 }, color = "metal" },
		{ name = "brake", parent = "barrel", shape = "cylinder", axis = "z", size = { 0.75, 0.75, 0.6 }, at = { 0, 3.0, -9.8 }, color = "dark" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 3.0, -10.2 } },
	},
}
