--!strict
-- Paladin (Order main battle tank, T2, footprint 1): the Lancer grown heavy
-- (M-14): a low broad hull behind thick skirts and a long glacis, a big
-- wedge turret with add-on armor cheeks and a rear bustle, a long gun with a
-- bore evacuator and muzzle brake (the weapon turns the turret; the gun has
-- no pitch piece). Team plates on the roof and skirts.
-- Model space, forward = -Z (docs/contracts/rig.md).

return {
	id = "ord_paladin",
	parts = {
		{ name = "base", shape = "box", size = { 5.8, 1.4, 7.0 }, at = { 0, 1.5, 0.4 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 5.8, 1.4, 1.6 }, at = { 0, 1.5, -3.9 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.2, 1.3, 8.2 }, at = { -2.9, 0.65, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.2, 1.3, 8.2 }, at = { 2.9, 0.65, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "skirtL", parent = "base", shape = "box", size = { 0.45, 1.3, 7.8 }, at = { -3.65, 1.2, 0 }, color = "hull" },
		{ name = "skirtR", parent = "base", shape = "box", size = { 0.45, 1.3, 7.8 }, at = { 3.65, 1.2, 0 }, color = "hull" },
		{ name = "skirtTeamL", parent = "base", shape = "box", size = { 0.06, 0.4, 4.0 }, at = { -3.9, 1.4, 0.4 }, color = "team" },
		{ name = "skirtTeamR", parent = "base", shape = "box", size = { 0.06, 0.4, 4.0 }, at = { 3.9, 1.4, 0.4 }, color = "team" },
		{ name = "deck", parent = "base", shape = "box", size = { 4.4, 0.3, 2.0 }, at = { 0, 2.35, 3.0 }, color = "dark" },
		{ name = "light", parent = "base", shape = "box", size = { 2.8, 0.12, 0.08 }, at = { 0, 1.2, -4.72 }, color = "glass" },

		{ name = "turret", parent = "base", shape = "box", size = { 4.6, 1.5, 4.4 }, at = { 0, 2.95, 0.6 }, pivot = { 0, 2.2, 0.3 }, color = "hull" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 4.6, 1.5, 1.4 }, at = { 0, 2.95, -2.3 }, color = "hull" },
		{ name = "cheekL", parent = "turret", shape = "box", size = { 0.6, 1.2, 2.6 }, at = { -2.55, 2.9, -0.6 }, color = "dark" },
		{ name = "cheekR", parent = "turret", shape = "box", size = { 0.6, 1.2, 2.6 }, at = { 2.55, 2.9, -0.6 }, color = "dark" },
		{ name = "bustle", parent = "turret", shape = "box", size = { 3.8, 1.1, 1.2 }, at = { 0, 3.0, 3.3 }, color = "hull" },
		{ name = "roofTeam", parent = "turret", shape = "box", size = { 3.4, 0.08, 3.0 }, at = { 0, 3.74, 0.9 }, color = "team" },
		{ name = "sight", parent = "turret", shape = "box", size = { 0.7, 0.5, 0.7 }, at = { 1.5, 3.95, -0.4 }, color = "dark" },
		{ name = "sightGlass", parent = "turret", shape = "box", size = { 0.5, 0.2, 0.05 }, at = { 1.5, 3.95, -0.77 }, color = "glass" },
		{ name = "mantlet", parent = "turret", shape = "box", size = { 1.4, 1.0, 0.6 }, at = { 0, 2.95, -3.1 }, color = "dark" },
		{ name = "gun", parent = "turret", shape = "cylinder", axis = "z", size = { 0.62, 0.62, 7.4 }, at = { 0, 2.95, -6.9 }, color = "metal" },
		{ name = "evacuator", parent = "turret", shape = "cylinder", axis = "z", size = { 0.85, 0.85, 1.1 }, at = { 0, 2.95, -6.2 }, color = "metal" },
		{ name = "brake", parent = "turret", shape = "box", size = { 1.0, 0.75, 0.8 }, at = { 0, 2.95, -10.6 }, color = "dark" },
	},
	attachments = {
		{ name = "muzzle", parent = "turret", at = { 0, 2.95, -11.05 } },
	},
}
