--!strict
-- Arbiter (Order mobile fire-control radar, T2, footprint 1): an armored
-- 8 × 8 truck with a boxy cab and a generator block; at the back the `dish`:
-- a big flat phased array (a panel, never a dish) on a turning plinth,
-- tilted back 20°, its face glowing. Team plates on the cab roof and the
-- plinth. Order reads heavy (M-14). Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 4.8, 1.3, 7.6 }, at = { 0, 1.75, 0.1 }, color = "hull" },
	{ name = "skirtL", parent = "base", shape = "box", size = { 0.3, 0.8, 6.8 }, at = { -2.55, 1.25, 0.1 }, color = "hull" },
	{ name = "skirtR", parent = "base", shape = "box", size = { 0.3, 0.8, 6.8 }, at = { 2.55, 1.25, 0.1 }, color = "hull" },
	{ name = "cab", parent = "base", shape = "box", size = { 4.6, 1.3, 1.8 }, at = { 0, 3.05, -2.8 }, color = "hull" },
	{ name = "cabGlass", parent = "base", shape = "box", size = { 3.8, 0.35, 0.08 }, at = { 0, 3.25, -3.74 }, color = "glass" },
	{ name = "cabTeam", parent = "base", shape = "box", size = { 3.4, 0.08, 1.2 }, at = { 0, 3.74, -2.8 }, color = "team" },
	{ name = "generator", parent = "base", shape = "box", size = { 3.6, 1.0, 1.6 }, at = { 0, 2.9, -0.8 }, color = "dark" },
	{ name = "plinth", parent = "base", shape = "cylinder", axis = "y", size = { 2.6, 0.6, 2.6 }, at = { 0, 2.7, 2.2 }, color = "hull" },
	{ name = "plinthTeam", parent = "base", shape = "box", size = { 1.2, 0.08, 1.2 }, at = { 0, 3.04, 3.3 }, color = "team" },

	{ name = "dish", parent = "base", shape = "box", size = { 4.2, 3.0, 0.4 }, at = { 0, 4.8, 2.2 }, rot = { -20, 0, 0 }, pivot = { 0, 3.0, 2.2 }, color = "hull" },
	{ name = "dishFace", parent = "dish", shape = "box", size = { 3.6, 2.4, 0.06 }, at = { 0, 4.8, 1.97 }, rot = { -20, 0, 0 }, color = "glass" },
	{ name = "dishStrut", parent = "dish", shape = "box", size = { 0.4, 1.4, 0.4 }, at = { 0, 3.6, 2.5 }, color = "dark" },
}
for i, z in { -2.9, -1.3, 1.3, 2.9 } do
	table.insert(parts, { name = `wheelL{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.7, 1.5, 1.5 }, at = { -2.2, 0.75, z }, color = "track" })
	table.insert(parts, { name = `wheelR{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.7, 1.5, 1.5 }, at = { 2.2, 0.75, z }, color = "track" })
end

return { id = "ord_arbiter", parts = parts }
