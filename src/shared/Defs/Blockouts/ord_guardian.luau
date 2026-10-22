--!strict
-- Guardian (Order attack helicopter, T1, footprint 1): an armored boxy
-- cabin with a stepped canopy, a long boom and team fin, skids; rocket
-- pods on the `pylon` stub wings (the weapon turns it); the main
-- `rotor` is spun by the client (visual piece). Model space, forward = -Z.

return {
	id = "ord_guardian",
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
		{ name = "stubs", parent = "base", shape = "box", size = { 3.4, 0.2, 0.8 }, at = { 0, 0.9, -0.4 }, color = "dark" },
		{ name = "pylon", parent = "base", shape = "box", size = { 3, 0.5, 0.9 }, at = { 0, 0.6, -0.4 }, color = "dark" },
		{ name = "podL", parent = "pylon", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 1.6 }, at = { -1.3, 0.55, -0.5 }, color = "metal" },
		{ name = "podR", parent = "pylon", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 1.6 }, at = { 1.3, 0.55, -0.5 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "pylon", at = { 0, 0.55, -1.4 } },
	},
}
