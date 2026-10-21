--!strict
-- Shipyard (Order, T1, footprint 5): two armored piers round a dock basin,
-- a closed hall across the back with a team roof, a gantry crane spanning
-- the basin, cyan lights on the pier heads. Sits on the water surface.
-- Model space, forward = -Z (docs/contracts/rig.md).

return {
	id = "ord_shipyard",
	parts = {
		{ name = "base", shape = "box", size = { 38, 0.6, 8 }, at = { 0, 0.3, 15 }, color = "dark" },
		{ name = "pierL", parent = "base", shape = "box", size = { 6, 2.4, 33 }, at = { -16, 1.2, -1.5 }, color = "hull" },
		{ name = "pierR", parent = "base", shape = "box", size = { 6, 2.4, 33 }, at = { 16, 1.2, -1.5 }, color = "hull" },
		{ name = "pierTipL", parent = "base", shape = "wedge", size = { 6, 2.4, 3 }, at = { -16, 1.2, -19.5 }, color = "hull" },
		{ name = "pierTipR", parent = "base", shape = "wedge", size = { 6, 2.4, 3 }, at = { 16, 1.2, -19.5 }, color = "hull" },
		{ name = "hall", parent = "base", shape = "box", size = { 26, 7, 7 }, at = { 0, 4.1, 15 }, color = "hull" },
		{ name = "hallTeam", parent = "base", shape = "box", size = { 20, 0.12, 5 }, at = { 0, 7.66, 15 }, color = "team" },
		{ name = "door", parent = "base", shape = "box", size = { 18, 5.5, 0.3 }, at = { 0, 3.4, 11.4 }, color = "dark" },
		{ name = "craneLegL", parent = "base", shape = "box", size = { 1, 9, 1 }, at = { -16, 6.9, -6 }, color = "metal" },
		{ name = "craneLegR", parent = "base", shape = "box", size = { 1, 9, 1 }, at = { 16, 6.9, -6 }, color = "metal" },
		{ name = "craneBeam", parent = "base", shape = "box", size = { 33, 1.4, 1.6 }, at = { 0, 11.8, -6 }, color = "hull" },
		{ name = "craneTeam", parent = "base", shape = "box", size = { 20, 0.1, 1.2 }, at = { 0, 12.55, -6 }, color = "team" },
		{ name = "lightL", parent = "base", shape = "box", size = { 0.8, 0.8, 0.8 }, at = { -16, 2.8, -17 }, color = "glass" },
		{ name = "lightR", parent = "base", shape = "box", size = { 0.8, 0.8, 0.8 }, at = { 16, 2.8, -17 }, color = "glass" },
	},
}
