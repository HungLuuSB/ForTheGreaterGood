--!strict
-- Depot (Order storage, T1, footprint 1): a low armored bunker with sloped
-- sides, two loading hatches and a team plate on the roof.
-- Model space, forward = -Z (docs/contracts/rig.md).

return {
	id = "ord_depot",
	parts = {
		{ name = "base", shape = "box", size = { 5.6, 2.2, 5.6 }, at = { 0, 1.1, 0 }, color = "hull" },
		{ name = "slopeF", parent = "base", shape = "wedge", size = { 5.6, 2.2, 0.9 }, at = { 0, 1.1, -3.25 }, color = "hull" },
		{ name = "slopeB", parent = "base", shape = "wedge", size = { 5.6, 2.2, 0.9 }, at = { 0, 1.1, 3.25 }, rot = { 0, 180, 0 }, color = "hull" },
		{ name = "slopeL", parent = "base", shape = "wedge", size = { 5.6, 2.2, 0.9 }, at = { -3.25, 1.1, 0 }, rot = { 0, 90, 0 }, color = "hull" },
		{ name = "slopeR", parent = "base", shape = "wedge", size = { 5.6, 2.2, 0.9 }, at = { 3.25, 1.1, 0 }, rot = { 0, -90, 0 }, color = "hull" },
		{ name = "team", parent = "base", shape = "box", size = { 4.4, 0.1, 2 }, at = { 0, 2.25, -1.2 }, color = "team" },
		{ name = "hatchA", parent = "base", shape = "box", size = { 1.6, 0.3, 1.6 }, at = { -1.2, 2.35, 1.4 }, color = "metal" },
		{ name = "hatchB", parent = "base", shape = "box", size = { 1.6, 0.3, 1.6 }, at = { 1.2, 2.35, 1.4 }, color = "metal" },
		{ name = "light", parent = "base", shape = "box", size = { 2, 0.2, 0.1 }, at = { 0, 1.9, -2.83 }, color = "glass" },
	},
}
