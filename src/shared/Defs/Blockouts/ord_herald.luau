--!strict
-- Herald (Order scout): small, low four-wheeler with a sloped nose and a
-- glass cab; a tiny gun turret on the rear deck. Model space, forward = -Z
-- (docs/contracts/rig.md).

return {
	id = "ord_herald",
	parts = {
		{ name = "base", shape = "box", size = { 3.8, 1.0, 5.0 }, at = { 0, 1.5, 0.4 }, color = "hull" },
		{ name = "nose", parent = "base", shape = "wedge", size = { 3.8, 1.0, 1.8 }, at = { 0, 1.5, -3.0 }, color = "hull" },
		{ name = "windshield", parent = "base", shape = "wedge", size = { 3.0, 0.6, 1.0 }, at = { 0, 2.3, -1.5 }, color = "glass" },
		{ name = "roof", parent = "base", shape = "box", size = { 3.0, 0.6, 1.4 }, at = { 0, 2.3, -0.3 }, color = "hull" },
		{ name = "wheelFL", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.5, 1.5 }, at = { -2.2, 0.75, -2.0 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "wheelFR", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.5, 1.5 }, at = { 2.2, 0.75, -2.0 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "wheelBL", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.5, 1.5 }, at = { -2.2, 0.75, 2.0 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "wheelBR", parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.5, 1.5 }, at = { 2.2, 0.75, 2.0 }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "antenna", parent = "base", shape = "box", size = { 0.08, 1.6, 0.08 }, at = { 1.4, 2.8, 2.6 }, color = "dark" },

		{ name = "turret", parent = "base", shape = "box", size = { 1.6, 0.6, 1.4 }, at = { 0, 2.3, 1.7 }, color = "team" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 1.6, 0.6, 0.6 }, at = { 0, 2.3, 0.7 }, color = "team" },
		{ name = "gun", parent = "turret", shape = "cylinder", axis = "z", size = { 0.25, 0.25, 2.0 }, at = { 0, 2.4, -0.2 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "turret", at = { 0, 2.4, -1.2 } },
	},
}
