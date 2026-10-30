--!strict
-- Charon (Chaos heavy air transport, T2, footprint 3; S-219): a flying
-- crane, the ferryman: a narrow spine with a cockpit pod at the front and a
-- lit lantern on a bow arm, twin exposed engines, a thin tail boom, four
-- long splayed legs, and an open cargo cradle with four chain hooks under
-- the spine (the `cargo` attachment in it: where the carried units hang);
-- client-spun six-blade `rotor`. Model space, forward = -Z.

return {
	id = "chs_charon",
	visualPieces = { "rotor" },
	parts = {
		{ name = "base", shape = "box", size = { 1.8, 2, 15.4 }, at = { 0, 4.9, -1.4 }, color = "hull" },
		{ name = "cockpit", parent = "base", shape = "box", size = { 2.8, 2.6, 4 }, at = { 0, 4.3, -10.2 }, color = "hull" },
		{ name = "windscreen", parent = "base", shape = "wedge", size = { 2.3, 1.4, 1.8 }, at = { 0, 4.9, -11.3 }, color = "glass" },
		{ name = "roofTeam", parent = "base", shape = "box", size = { 1.1, 0.06, 4.4 }, at = { 0, 5.95, -3.4 }, color = "team" },
		{ name = "lantern", parent = "base", shape = "cylinder", axis = "y", size = { 0.52, 0.6, 0.52 }, at = { 0, 3.25, -13.4 }, color = "glass" },
		{ name = "engineL", parent = "base", shape = "cylinder", axis = "z", size = { 1.3, 1.3, 4.2 }, at = { -1.35, 6.1, -1 }, color = "metal" },
		{ name = "engineR", parent = "base", shape = "cylinder", axis = "z", size = { 1.3, 1.3, 4.2 }, at = { 1.35, 6.1, -1 }, color = "metal" },
		{ name = "boom", parent = "base", shape = "box", size = { 0.5, 0.5, 6.6 }, at = { 0, 5, 10.2 }, color = "metal" },
		{ name = "fin", parent = "base", shape = "box", size = { 0.2, 2.3, 1.8 }, at = { 0, 6.05, 13.3 }, color = "team" },
		{ name = "legFL", parent = "base", shape = "box", size = { 0.24, 4.6, 0.24 }, at = { -2.2, 2.2, -6.8 }, rot = { 0, 0, -38 }, color = "metal" },
		{ name = "legFR", parent = "base", shape = "box", size = { 0.24, 4.6, 0.24 }, at = { 2.2, 2.2, -6.8 }, rot = { 0, 0, 38 }, color = "metal" },
		{ name = "legBL", parent = "base", shape = "box", size = { 0.24, 4.6, 0.24 }, at = { -2.2, 2.2, 4.9 }, rot = { 0, 0, -38 }, color = "metal" },
		{ name = "legBR", parent = "base", shape = "box", size = { 0.24, 4.6, 0.24 }, at = { 2.2, 2.2, 4.9 }, rot = { 0, 0, 38 }, color = "metal" },
		{ name = "cradleL", parent = "base", shape = "box", size = { 0.22, 0.22, 9.2 }, at = { -2, 2.4, -0.8 }, color = "dark" },
		{ name = "cradleR", parent = "base", shape = "box", size = { 0.22, 0.22, 9.2 }, at = { 2, 2.4, -0.8 }, color = "dark" },
		{ name = "cradleX", parent = "base", shape = "box", size = { 4, 0.18, 0.18 }, at = { 0, 2.4, -0.8 }, color = "dark" },
		{ name = "mast", parent = "base", shape = "cylinder", axis = "y", size = { 0.64, 1.4, 0.64 }, at = { 0, 6.7, -1.2 }, color = "metal" },
		{ name = "rotor", parent = "base", shape = "box", size = { 20.2, 0.12, 0.7 }, at = { 0, 7.6, -1.2 }, color = "dark", anim = { motion = "spin", axis = { 0, 1, 0 } } },
		{ name = "blade2", parent = "rotor", shape = "box", size = { 20.2, 0.12, 0.7 }, at = { 0, 7.6, -1.2 }, rot = { 0, 60, 0 }, color = "dark" },
		{ name = "blade3", parent = "rotor", shape = "box", size = { 20.2, 0.12, 0.7 }, at = { 0, 7.6, -1.2 }, rot = { 0, -60, 0 }, color = "dark" },
		{ name = "tailRotor", parent = "base", shape = "cylinder", axis = "x", size = { 0.12, 3.6, 3.6 }, at = { 0.42, 6, 13.4 }, color = "dark", anim = { motion = "spin", axis = { 1, 0, 0 } } },
	},
	attachments = {
		{ name = "cargo", parent = "base", at = { 0, 0.8, -0.8 } },
	},
}
