--!strict
-- Courier (Order light air transport, T1, footprint 2; S-219): an armored
-- utility lifter a size up from the Skywright, with fuel sponsons, team door
-- plates, a tall-skid undercarriage and a cargo winch between the skids (the
-- `cargo` attachment: where a carried unit hangs); client-spun `rotor`.
-- Model space, forward = -Z.

return {
	id = "ord_courier",
	visualPieces = { "rotor" },
	parts = {
		{ name = "base", shape = "box", size = { 2.8, 2.2, 9.4 }, at = { 0, 2.1, -1.5 }, color = "hull" },
		{ name = "nose", parent = "base", shape = "wedge", size = { 2.8, 1.4, 1.6 }, at = { 0, 1.7, -5.4 }, color = "hull" },
		{ name = "canopy", parent = "base", shape = "wedge", size = { 2.4, 1, 2.2 }, at = { 0, 2.8, -4.5 }, color = "glass" },
		{ name = "doorL", parent = "base", shape = "box", size = { 0.06, 1.1, 2.6 }, at = { -1.43, 2.05, -0.6 }, color = "team" },
		{ name = "doorR", parent = "base", shape = "box", size = { 0.06, 1.1, 2.6 }, at = { 1.43, 2.05, -0.6 }, color = "team" },
		{ name = "sponsonL", parent = "base", shape = "box", size = { 0.7, 0.9, 2.8 }, at = { -1.78, 1.75, 1.6 }, color = "hull" },
		{ name = "sponsonR", parent = "base", shape = "box", size = { 0.7, 0.9, 2.8 }, at = { 1.78, 1.75, 1.6 }, color = "hull" },
		{ name = "cowl", parent = "base", shape = "box", size = { 2.2, 0.7, 3.4 }, at = { 0, 3.55, 0.5 }, color = "metal" },
		{ name = "boom", parent = "base", shape = "box", size = { 0.9, 0.8, 6.8 }, at = { 0, 2.7, 6.6 }, color = "hull" },
		{ name = "fin", parent = "base", shape = "box", size = { 0.2, 1.8, 1.4 }, at = { 0, 4.1, 10.2 }, color = "team" },
		{ name = "stabilizer", parent = "base", shape = "box", size = { 3, 0.14, 0.9 }, at = { 0, 2.95, 8.8 }, color = "hull" },
		{ name = "skidL", parent = "base", shape = "box", size = { 0.2, 0.2, 6 }, at = { -1.6, 0.1, -0.6 }, color = "dark" },
		{ name = "skidR", parent = "base", shape = "box", size = { 0.2, 0.2, 6 }, at = { 1.6, 0.1, -0.6 }, color = "dark" },
		{ name = "winch", parent = "base", shape = "box", size = { 1.2, 0.6, 1.2 }, at = { 0, 0.7, -0.4 }, color = "metal" },
		{ name = "mast", parent = "base", shape = "cylinder", axis = "y", size = { 0.5, 0.7, 0.5 }, at = { 0, 4.1, -0.6 }, color = "metal" },
		{ name = "rotor", parent = "base", shape = "box", size = { 13.8, 0.12, 0.55 }, at = { 0, 4.4, -0.6 }, color = "dark", anim = { motion = "spin", axis = { 0, 1, 0 } } },
		{ name = "blade2", parent = "rotor", shape = "box", size = { 0.55, 0.12, 13.8 }, at = { 0, 4.4, -0.6 }, color = "dark" },
		{ name = "tailRotor", parent = "base", shape = "cylinder", axis = "x", size = { 0.12, 2.5, 2.5 }, at = { 0.32, 4.1, 10.3 }, color = "dark", anim = { motion = "spin", axis = { 1, 0, 0 } } },
	},
	attachments = {
		{ name = "cargo", parent = "base", at = { 0, 0.25, -0.4 } },
	},
}
