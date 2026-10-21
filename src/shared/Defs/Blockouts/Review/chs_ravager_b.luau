--!strict
-- Ravager variant B (Chaos, T-14 Armata lines), for the style review: longer
-- hull with seven road wheels, reactive-armor panels on the front of the
-- skirts and a slat cage across the rear; a tall, faceted unmanned turret
-- with flat-panel protection radars, two sensor boxes, a remote gun and
-- active-protection launchers; long gun. Gunmetal. Model space,
-- forward = -Z (docs/contracts/rig.md).

return {
	id = "chs_ravager",
	parts = {
		{ name = "base", shape = "box", size = { 5.8, 1.0, 7.8 }, at = { 0, 1.4, 0.1 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 5.8, 1.0, 1.0 }, at = { 0, 1.4, -4.3 }, color = "hull" },
		{ name = "deck", parent = "base", shape = "box", size = { 4.4, 0.1, 1.8 }, at = { 0, 1.95, 3.0 }, color = "dark" },
		{ name = "beltL", parent = "base", shape = "box", size = { 0.9, 0.2, 8.0 }, at = { -2.45, 0.1, 0 }, color = "track" },
		{ name = "beltR", parent = "base", shape = "box", size = { 0.9, 0.2, 8.0 }, at = { 2.45, 0.1, 0 }, color = "track" },
		{ name = "wheelL1", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.0, 1.0 }, at = { -2.45, 0.55, -3.3 }, color = "track" },
		{ name = "wheelL2", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.0, 1.0 }, at = { -2.45, 0.55, -2.2 }, color = "track" },
		{ name = "wheelL3", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.0, 1.0 }, at = { -2.45, 0.55, -1.1 }, color = "track" },
		{ name = "wheelL4", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.0, 1.0 }, at = { -2.45, 0.55, 0 }, color = "track" },
		{ name = "wheelL5", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.0, 1.0 }, at = { -2.45, 0.55, 1.1 }, color = "track" },
		{ name = "wheelL6", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.0, 1.0 }, at = { -2.45, 0.55, 2.2 }, color = "track" },
		{ name = "wheelL7", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.0, 1.0 }, at = { -2.45, 0.55, 3.3 }, color = "track" },
		{ name = "wheelR1", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.0, 1.0 }, at = { 2.45, 0.55, -3.3 }, color = "track" },
		{ name = "wheelR2", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.0, 1.0 }, at = { 2.45, 0.55, -2.2 }, color = "track" },
		{ name = "wheelR3", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.0, 1.0 }, at = { 2.45, 0.55, -1.1 }, color = "track" },
		{ name = "wheelR4", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.0, 1.0 }, at = { 2.45, 0.55, 0 }, color = "track" },
		{ name = "wheelR5", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.0, 1.0 }, at = { 2.45, 0.55, 1.1 }, color = "track" },
		{ name = "wheelR6", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.0, 1.0 }, at = { 2.45, 0.55, 2.2 }, color = "track" },
		{ name = "wheelR7", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.0, 1.0 }, at = { 2.45, 0.55, 3.3 }, color = "track" },
		{ name = "skirtL", parent = "base", shape = "box", size = { 0.25, 1.0, 8.2 }, at = { -3.0, 1.3, 0 }, color = "hull" },
		{ name = "skirtR", parent = "base", shape = "box", size = { 0.25, 1.0, 8.2 }, at = { 3.0, 1.3, 0 }, color = "hull" },
		{ name = "eraL1", parent = "base", shape = "box", size = { 0.15, 0.8, 1.0 }, at = { -3.18, 1.3, -3.4 }, color = "dark" },
		{ name = "eraL2", parent = "base", shape = "box", size = { 0.15, 0.8, 1.0 }, at = { -3.18, 1.3, -2.3 }, color = "dark" },
		{ name = "eraL3", parent = "base", shape = "box", size = { 0.15, 0.8, 1.0 }, at = { -3.18, 1.3, -1.2 }, color = "dark" },
		{ name = "eraR1", parent = "base", shape = "box", size = { 0.15, 0.8, 1.0 }, at = { 3.18, 1.3, -3.4 }, color = "dark" },
		{ name = "eraR2", parent = "base", shape = "box", size = { 0.15, 0.8, 1.0 }, at = { 3.18, 1.3, -2.3 }, color = "dark" },
		{ name = "eraR3", parent = "base", shape = "box", size = { 0.15, 0.8, 1.0 }, at = { 3.18, 1.3, -1.2 }, color = "dark" },
		{ name = "stripeL", parent = "base", shape = "box", size = { 0.06, 0.3, 2.0 }, at = { -3.14, 1.3, 1.6 }, color = "team" },
		{ name = "stripeR", parent = "base", shape = "box", size = { 0.06, 0.3, 2.0 }, at = { 3.14, 1.3, 1.6 }, color = "team" },
		{ name = "slatTop", parent = "base", shape = "box", size = { 5.4, 0.08, 0.08 }, at = { 0, 1.95, 4.25 }, color = "dark" },
		{ name = "slatLow", parent = "base", shape = "box", size = { 5.4, 0.08, 0.08 }, at = { 0, 1.15, 4.25 }, color = "dark" },
		{ name = "slat1", parent = "base", shape = "box", size = { 0.08, 0.8, 0.08 }, at = { -2.0, 1.55, 4.25 }, color = "dark" },
		{ name = "slat2", parent = "base", shape = "box", size = { 0.08, 0.8, 0.08 }, at = { -0.7, 1.55, 4.25 }, color = "dark" },
		{ name = "slat3", parent = "base", shape = "box", size = { 0.08, 0.8, 0.08 }, at = { 0.7, 1.55, 4.25 }, color = "dark" },
		{ name = "slat4", parent = "base", shape = "box", size = { 0.08, 0.8, 0.08 }, at = { 2.0, 1.55, 4.25 }, color = "dark" },

		{ name = "turret", parent = "base", shape = "box", size = { 3.4, 1.1, 3.4 }, at = { 0, 2.45, 1.1 }, color = "hull" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 3.4, 1.1, 1.2 }, at = { 0, 2.45, -1.2 }, color = "hull" },
		{ name = "radarL", parent = "turret", shape = "box", size = { 0.08, 0.5, 0.7 }, at = { -1.74, 2.55, -0.1 }, color = "glass" },
		{ name = "radarR", parent = "turret", shape = "box", size = { 0.08, 0.5, 0.7 }, at = { 1.74, 2.55, -0.1 }, color = "glass" },
		{ name = "sensorL", parent = "turret", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { -1.0, 3.25, -0.1 }, color = "dark" },
		{ name = "sensorR", parent = "turret", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { 1.0, 3.25, -0.1 }, color = "dark" },
		{ name = "rws", parent = "turret", shape = "box", size = { 0.7, 0.5, 0.8 }, at = { 0.3, 3.25, 1.6 }, color = "dark" },
		{ name = "rwsGun", parent = "turret", shape = "cylinder", axis = "z", size = { 0.15, 0.15, 1.0 }, at = { 0.3, 3.3, 0.8 }, color = "metal" },
		{ name = "apsL", parent = "turret", shape = "box", size = { 0.5, 0.4, 0.6 }, at = { -1.95, 2.1, 0.8 }, color = "dark" },
		{ name = "apsR", parent = "turret", shape = "box", size = { 0.5, 0.4, 0.6 }, at = { 1.95, 2.1, 0.8 }, color = "dark" },
		{ name = "roofPanel", parent = "turret", shape = "box", size = { 1.2, 0.06, 0.9 }, at = { -0.9, 3.03, 1.9 }, color = "team" },
		{ name = "panelL", parent = "turret", shape = "box", size = { 0.06, 0.35, 1.4 }, at = { -1.73, 2.5, 1.9 }, color = "team" },
		{ name = "panelR", parent = "turret", shape = "box", size = { 0.06, 0.35, 1.4 }, at = { 1.73, 2.5, 1.9 }, color = "team" },

		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.38, 0.38, 6.4 }, at = { 0, 2.5, -4.6 }, pivot = { 0, 2.5, -1.4 }, color = "metal" },
		{ name = "mantlet", parent = "barrel", shape = "box", size = { 0.8, 0.7, 0.3 }, at = { 0, 2.5, -1.85 }, color = "dark" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 2.5, -7.8 } },
	},
}
