--!strict
-- Barrier (Order wall segment, T1 structure, proposed footprint 1;
-- docs/design/factions.md): a thick armored wall block with sloped faces on
-- both sides and a capping beam, a team stripe along the top. Segments line
-- up along X (8 studs per cell). Model space, forward = -Z.

return {
	id = "ord_barrier",
	parts = {
		{ name = "base", shape = "box", size = { 7.8, 2.8, 1.8 }, at = { 0, 1.4, 0 }, color = "hull" },
		{ name = "slopeF", parent = "base", shape = "wedge", size = { 7.8, 2.4, 1.4 }, at = { 0, 1.2, -1.6 }, color = "hull" },
		{ name = "slopeB", parent = "base", shape = "wedge", size = { 7.8, 2.4, 1.4 }, at = { 0, 1.2, 1.6 }, rot = { 0, 180, 0 }, color = "hull" },
		{ name = "cap", parent = "base", shape = "box", size = { 7.8, 0.4, 2.2 }, at = { 0, 3.0, 0 }, color = "dark" },
		{ name = "stripe", parent = "base", shape = "box", size = { 6.8, 0.08, 1.0 }, at = { 0, 3.24, 0 }, color = "team" },
		{ name = "lightL", parent = "base", shape = "box", size = { 0.3, 0.3, 0.3 }, at = { -3.6, 3.35, 0 }, color = "glass" },
		{ name = "lightR", parent = "base", shape = "box", size = { 0.3, 0.3, 0.3 }, at = { 3.6, 3.35, 0 }, color = "glass" },
	},
}
