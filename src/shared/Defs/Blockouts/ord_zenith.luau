--!strict
-- Zenith (Order advanced air builder, T2, footprint 1): the Skywright's
-- airframe with side pods, a belly cargo pod and a second `nano`
-- emitter arm; client-spun `rotor`. Model space, forward = -Z.

return {
	id = "ord_zenith",
	visualPieces = { "rotor" },
	parts = {
		{ name = "base", shape = "box", size = { 1.8, 1.5, 4.2 }, at = { 0, 1.1, -0.4 }, color = "hull" },
		{ name = "nose", parent = "base", shape = "wedge", size = { 1.8, 1.2, 1.4 }, at = { 0, 0.95, -3.2 }, color = "hull" },
		{ name = "canopy", parent = "base", shape = "wedge", size = { 1.4, 0.8, 1.4 }, at = { 0, 1.8, -2.2 }, color = "glass" },
		{ name = "boom", parent = "base", shape = "box", size = { 0.5, 0.5, 4 }, at = { 0, 1.3, 3.6 }, color = "hull" },
		{ name = "fin", parent = "base", shape = "box", size = { 0.15, 1.6, 0.9 }, at = { 0, 2, 5.4 }, color = "team" },
		{ name = "stabilizer", parent = "base", shape = "box", size = { 1.8, 0.12, 0.6 }, at = { 0, 1.4, 5 }, color = "hull" },
		{ name = "roofTeam", parent = "base", shape = "box", size = { 1.2, 0.06, 1.6 }, at = { 0, 1.88, 0.4 }, color = "team" },
		{ name = "skidL", parent = "base", shape = "box", size = { 0.15, 0.15, 4.4 }, at = { -0.9, 0.08, -0.4 }, color = "dark" },
		{ name = "skidR", parent = "base", shape = "box", size = { 0.15, 0.15, 4.4 }, at = { 0.9, 0.08, -0.4 }, color = "dark" },
		{ name = "mast", parent = "base", shape = "cylinder", axis = "y", size = { 0.35, 0.6, 0.35 }, at = { 0, 2.45, 0.2 }, color = "metal" },
		{ name = "rotor", parent = "base", shape = "box", size = { 8.6, 0.12, 0.45 }, at = { 0, 2.8, 0.2 }, color = "dark", anim = { motion = "spin", axis = { 0, 1, 0 } } },
		{ name = "blade2", parent = "rotor", shape = "box", size = { 0.45, 0.12, 8.6 }, at = { 0, 2.8, 0.2 }, color = "dark" },
		{ name = "tailRotor", parent = "base", shape = "cylinder", axis = "x", size = { 0.12, 1.6, 1.6 }, at = { 0.2, 2, 5.4 }, color = "dark", anim = { motion = "spin", axis = { 1, 0, 0 } } },
		{ name = "nano", parent = "base", shape = "cylinder", axis = "y", size = { 1.2, 0.3, 1.2 }, at = { 0, 0.25, -0.2 }, color = "team" },
		{ name = "nanoArm", parent = "nano", shape = "box", size = { 0.3, 0.3, 1.6 }, at = { 0, 0, -0.9 }, rot = { 20, 0, 0 }, color = "dark" },
		{ name = "emitter", parent = "nano", shape = "ball", size = { 0.7, 0.7, 0.7 }, at = { 0, -0.3, -1.7 }, color = "glass" },
		{ name = "cargo", parent = "base", shape = "box", size = { 1.4, 0.7, 2 }, at = { 0, 0.25, 1.4 }, color = "dark" },
		{ name = "nanoArm2", parent = "nano", shape = "box", size = { 0.3, 0.3, 1.6 }, at = { 0, 0, 0.5 }, rot = { -20, 0, 0 }, color = "dark" },
		{ name = "emitter2", parent = "nano", shape = "ball", size = { 0.6, 0.6, 0.6 }, at = { 0, -0.3, 1.2 }, color = "glass" },
		{ name = "podL", parent = "base", shape = "box", size = { 0.4, 0.6, 1.6 }, at = { -1.1, 1, 0 }, color = "hull" },
		{ name = "podR", parent = "base", shape = "box", size = { 0.4, 0.6, 1.6 }, at = { 1.1, 1, 0 }, color = "hull" },
	},
	-- nanoframe anchors (M-25, rig.md 8)
	attachments = {
		{ name = "nano1", parent = "nano", at = { 0, -0.3, -1.7 } },
		{ name = "nano2", parent = "nano", at = { 0, -0.3, 1.2 } },
	},
}
