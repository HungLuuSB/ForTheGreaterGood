--!strict
-- Ark (Order heavy air transport, T2, footprint 3; S-219): a tandem-rotor
-- heavy lifter, a long armored fuselage with sponsons and wheels, a loading
-- ramp, a low front pylon and a tall aft pylon with twin engines, and two
-- cargo hooks under the belly (the `cargo` attachment between them: where
-- the carried units hang). The client-spun `rotor` is the front rotor; the
-- aft one is `tailRotor`, turning the other way (axis -Y). Model space,
-- forward = -Z.

return {
	id = "ord_ark",
	visualPieces = { "rotor" },
	parts = {
		{ name = "base", shape = "box", size = { 4.4, 3.6, 17.2 }, at = { 0, 3.1, -1.4 }, color = "hull" },
		{ name = "nose", parent = "base", shape = "wedge", size = { 4.4, 2.2, 2.2 }, at = { 0, 3.8, -9.7 }, color = "hull" },
		{ name = "canopy", parent = "base", shape = "wedge", size = { 3.8, 1, 2.2 }, at = { 0, 4.4, -8.8 }, color = "glass" },
		{ name = "tail", parent = "base", shape = "box", size = { 4.4, 2.3, 3 }, at = { 0, 3.75, 8.1 }, color = "hull" },
		{ name = "ramp", parent = "base", shape = "box", size = { 3.4, 2.6, 0.06 }, at = { 0, 3, 9.62 }, color = "dark" },
		{ name = "roofTeam", parent = "base", shape = "box", size = { 1.6, 0.06, 11 }, at = { 0, 4.93, -1.5 }, color = "team" },
		{ name = "sponsonL", parent = "base", shape = "box", size = { 1.3, 1.3, 7.6 }, at = { -2.95, 1.75, 0.2 }, color = "hull" },
		{ name = "sponsonR", parent = "base", shape = "box", size = { 1.3, 1.3, 7.6 }, at = { 2.95, 1.75, 0.2 }, color = "hull" },
		{ name = "sideTeamL", parent = "base", shape = "box", size = { 0.06, 1.2, 3.4 }, at = { -2.23, 3.25, 4.6 }, color = "team" },
		{ name = "sideTeamR", parent = "base", shape = "box", size = { 0.06, 1.2, 3.4 }, at = { 2.23, 3.25, 4.6 }, color = "team" },
		{ name = "gearFL", parent = "base", shape = "cylinder", axis = "x", size = { 0.5, 1.1, 1.1 }, at = { -2.95, 0.55, -2.2 }, color = "track" },
		{ name = "gearFR", parent = "base", shape = "cylinder", axis = "x", size = { 0.5, 1.1, 1.1 }, at = { 2.95, 0.55, -2.2 }, color = "track" },
		{ name = "gearBL", parent = "base", shape = "cylinder", axis = "x", size = { 0.5, 1.1, 1.1 }, at = { -2.95, 0.55, 2.6 }, color = "track" },
		{ name = "gearBR", parent = "base", shape = "cylinder", axis = "x", size = { 0.5, 1.1, 1.1 }, at = { 2.95, 0.55, 2.6 }, color = "track" },
		{ name = "frontPylon", parent = "base", shape = "box", size = { 2, 0.9, 2.8 }, at = { 0, 5.35, -7 }, color = "metal" },
		{ name = "aftPylon", parent = "base", shape = "box", size = { 2.4, 1.8, 6.6 }, at = { 0, 5.8, 6.3 }, color = "hull" },
		{ name = "engineL", parent = "base", shape = "cylinder", axis = "z", size = { 1.2, 1.2, 3.6 }, at = { -1.75, 5.8, 5 }, color = "metal" },
		{ name = "engineR", parent = "base", shape = "cylinder", axis = "z", size = { 1.2, 1.2, 3.6 }, at = { 1.75, 5.8, 5 }, color = "metal" },
		{ name = "hookF", parent = "base", shape = "box", size = { 1.4, 0.6, 1 }, at = { 0, 1, -3 }, color = "metal" },
		{ name = "hookB", parent = "base", shape = "box", size = { 1.4, 0.6, 1 }, at = { 0, 1, 3 }, color = "metal" },
		{ name = "rotor", parent = "base", shape = "box", size = { 16.2, 0.14, 0.75 }, at = { 0, 6.3, -7 }, color = "dark", anim = { motion = "spin", axis = { 0, 1, 0 } } },
		{ name = "blade2", parent = "rotor", shape = "box", size = { 0.75, 0.14, 16.2 }, at = { 0, 6.3, -7 }, color = "dark" },
		{ name = "tailRotor", parent = "base", shape = "box", size = { 16.2, 0.14, 0.75 }, at = { 0, 7.4, 7.6 }, color = "dark", anim = { motion = "spin", axis = { 0, -1, 0 } } },
		{ name = "blade4", parent = "tailRotor", shape = "box", size = { 0.75, 0.14, 16.2 }, at = { 0, 7.4, 7.6 }, color = "dark" },
	},
	attachments = {
		{ name = "cargo", parent = "base", at = { 0, 0.4, 0 } },
	},
}
