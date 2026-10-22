--!strict
-- Tideguard (Order amphibious tank, T2, footprint 1): a boat-bowed armored
-- hull on low tracks, sealed and smooth, two waterjet housings at the stern,
-- a snorkel; a compact turret with a short gun (the weapon turns the turret,
-- no pitch piece). Team plates on the turret roof and bow.
-- Model space, forward = -Z.

return {
	id = "ord_tideguard",
	parts = {
		{ name = "base", shape = "box", size = { 5.6, 1.6, 6.0 }, at = { 0, 1.6, 0.8 }, color = "hull" },
		{ name = "bow", parent = "base", shape = "wedge", size = { 5.6, 1.6, 2.2 }, at = { 0, 1.6, -3.3 }, color = "hull" },
		{ name = "bowTeam", parent = "base", shape = "box", size = { 3.6, 0.08, 1.2 }, at = { 0, 2.44, -1.6 }, color = "team" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.0, 0.9, 7.0 }, at = { -2.6, 0.45, 0.2 }, color = "track" },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.0, 0.9, 7.0 }, at = { 2.6, 0.45, 0.2 }, color = "track" },
		{ name = "jetL", parent = "base", shape = "cylinder", axis = "z", size = { 1.0, 1.0, 1.0 }, at = { -1.6, 1.2, 4.2 }, color = "dark" },
		{ name = "jetR", parent = "base", shape = "cylinder", axis = "z", size = { 1.0, 1.0, 1.0 }, at = { 1.6, 1.2, 4.2 }, color = "dark" },
		{ name = "snorkel", parent = "base", shape = "box", size = { 0.35, 1.8, 0.35 }, at = { -2.2, 3.3, 3.0 }, color = "dark" },

		{ name = "turret", parent = "base", shape = "box", size = { 3.4, 1.2, 3.2 }, at = { 0, 3.0, 1.0 }, pivot = { 0, 2.4, 1.0 }, color = "hull" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 3.4, 1.2, 1.0 }, at = { 0, 3.0, -1.1 }, color = "hull" },
		{ name = "roofTeam", parent = "turret", shape = "box", size = { 2.4, 0.08, 2.2 }, at = { 0, 3.64, 1.2 }, color = "team" },
		{ name = "sight", parent = "turret", shape = "box", size = { 0.4, 0.2, 0.05 }, at = { 1.1, 3.3, -0.62 }, color = "glass" },
		{ name = "gun", parent = "turret", shape = "cylinder", axis = "z", size = { 0.45, 0.45, 4.0 }, at = { 0, 3.0, -3.2 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "turret", at = { 0, 3.0, -5.2 } },
	},
}
