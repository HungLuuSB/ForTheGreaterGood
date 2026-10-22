--!strict
-- Airpad (Order rearm pad, T1, footprint 3): an armored square apron with a
-- landing circle ringed in team color, edge lights, a rearm arm and a fuel
-- block. Model space, forward = -Z.

return {
	id = "ord_airpad",
	parts = {
		{ name = "base", shape = "box", size = { 22, 0.6, 22 }, at = { 0, 0.3, 0 }, color = "hull" },
		{ name = "pad", parent = "base", shape = "cylinder", axis = "y", size = { 14, 0.2, 14 }, at = { 0, 0.7, 0 }, color = "dark" },
		{ name = "ring", parent = "base", shape = "cylinder", axis = "y", size = { 14.4, 0.15, 14.4 }, at = { 0, 0.66, 0 }, color = "team" },
		{ name = "markA", parent = "base", shape = "box", size = { 0.6, 0.06, 6 }, at = { -1.6, 0.83, 0 }, color = "hull" },
		{ name = "markB", parent = "base", shape = "box", size = { 0.6, 0.06, 6 }, at = { 1.6, 0.83, 0 }, color = "hull" },
		{ name = "markC", parent = "base", shape = "box", size = { 3.2, 0.06, 0.6 }, at = { 0, 0.83, 0 }, color = "hull" },
		{ name = "light0", parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { -9, 0.85, -9 }, color = "glass" },
		{ name = "light1", parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { 9, 0.85, -9 }, color = "glass" },
		{ name = "light2", parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { -9, 0.85, 9 }, color = "glass" },
		{ name = "light3", parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { 9, 0.85, 9 }, color = "glass" },
		{ name = "armL", parent = "base", shape = "box", size = { 1.2, 2.4, 1.2 }, at = { -9.4, 1.8, 0 }, color = "hull" },
		{ name = "armBoom", parent = "base", shape = "box", size = { 3.6, 0.6, 0.6 }, at = { -7.6, 3, 0 }, color = "hull" },
		{ name = "fuel", parent = "base", shape = "box", size = { 3, 1.6, 2 }, at = { 8.6, 1.4, -6 }, color = "hull" },
		{ name = "fuelTeam", parent = "base", shape = "box", size = { 2.2, 0.08, 1.2 }, at = { 8.6, 2.24, -6 }, color = "team" },
	},
}
