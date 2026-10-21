--!strict
-- Generator (Order, T1, footprint 1): a solid armored block with a domed
-- reactor cap, cyan vent strips on the sides and a team plate on top.
-- Model space, forward = -Z (docs/contracts/rig.md).

return {
	id = "ord_generator",
	parts = {
		{ name = "base", shape = "box", size = { 7.4, 0.5, 7.4 }, at = { 0, 0.25, 0 }, color = "dark" },
		{ name = "block", parent = "base", shape = "box", size = { 6, 3, 6 }, at = { 0, 2, 0 }, color = "hull" },
		{ name = "dome", parent = "base", shape = "cylinder", axis = "y", size = { 4.2, 1.2, 4.2 }, at = { 0, 4.1, 0 }, color = "hull" },
		{ name = "domeTop", parent = "base", shape = "cylinder", axis = "y", size = { 2.8, 0.6, 2.8 }, at = { 0, 5.0, 0 }, color = "metal" },
		{ name = "core", parent = "base", shape = "cylinder", axis = "y", size = { 1.4, 0.3, 1.4 }, at = { 0, 5.45, 0 }, color = "glass" },
		{ name = "teamF", parent = "base", shape = "box", size = { 4.4, 0.1, 1 }, at = { 0, 3.55, -2.4 }, color = "team" },
		{ name = "teamB", parent = "base", shape = "box", size = { 4.4, 0.1, 1 }, at = { 0, 3.55, 2.4 }, color = "team" },
		{ name = "ventL", parent = "base", shape = "box", size = { 0.1, 0.4, 4 }, at = { -3.05, 2.3, 0 }, color = "glass" },
		{ name = "ventR", parent = "base", shape = "box", size = { 0.1, 0.4, 4 }, at = { 3.05, 2.3, 0 }, color = "glass" },
	},
}
