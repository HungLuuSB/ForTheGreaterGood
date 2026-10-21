--!strict
-- Augur (Chaos Pinpointer, T2, footprint 2): a light frame on a pad with a
-- turning flat array on a lattice mast (the def's `dish` piece; flat
-- panels, never dishes) and an orange eye, team plate on the pad.
-- Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "cylinder", axis = "y", size = { 12, 0.8, 12 }, at = { 0, 0.4, 0 }, color = "dark" },
	{ name = "team", parent = "base", shape = "box", size = { 3.4, 0.1, 3.4 }, at = { 3.2, 0.85, 3.2 }, color = "team" },
	{ name = "eye", parent = "base", shape = "ball", size = { 1.2, 1.2, 1.2 }, at = { 0, 5.0, -1.2 }, color = "glass" },
	{ name = "dish", parent = "base", shape = "box", size = { 6.4, 3.2, 0.4 }, at = { 0, 7.8, 0 }, rot = { 20, 0, 0 }, pivot = { 0, 6.2, 0 }, color = "hull" },
	{ name = "dishTeam", parent = "dish", shape = "box", size = { 5.8, 0.4, 0.08 }, at = { 0, 9.18, 0.74 }, rot = { 20, 0, 0 }, color = "team" },
}
for i, p in { { -1.4, -1.4 }, { 1.4, -1.4 }, { -1.4, 1.4 }, { 1.4, 1.4 } } do
	table.insert(parts, { name = `leg{i}`, parent = "base", shape = "box", size = { 0.3, 5.8, 0.3 }, at = { p[1] * 0.7, 3.3, p[2] * 0.7 }, rot = { p[2] > 0 and -5 or 5, 0, p[1] > 0 and 5 or -5 }, color = "dark" })
end

return { id = "chs_augur", parts = parts }
