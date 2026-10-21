--!strict
-- Deepear (Chaos sonar station, T2, footprint 3): a pontoon platform of
-- round floats and an open deck frame, a sonar drum with a glowing ring
-- hanging below it, a lattice mast with a small panel, team plates.
-- Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 16, 0.6, 16 }, at = { 0, 1.1, 0 }, color = "dark" },
	{ name = "drum", parent = "base", shape = "cylinder", axis = "y", size = { 6, 2.4, 6 }, at = { 0, 0.2, 0 }, color = "hull" },
	{ name = "ring", parent = "base", shape = "cylinder", axis = "y", size = { 6.2, 0.3, 6.2 }, at = { 0, 0.9, 0 }, color = "glass" },
	{ name = "teamA", parent = "base", shape = "box", size = { 3.4, 0.1, 3.4 }, at = { -5, 1.45, 5 }, color = "team" },
	{ name = "teamB", parent = "base", shape = "box", size = { 3.4, 0.1, 3.4 }, at = { 5, 1.45, -5 }, color = "team" },
	{ name = "mast", parent = "base", shape = "box", size = { 0.5, 7, 0.5 }, at = { 5, 4.9, 5 }, color = "dark" },
	{ name = "mastBrace", parent = "base", shape = "box", size = { 0.25, 6, 0.25 }, at = { 5.9, 4.4, 5 }, rot = { 0, 0, 10 }, color = "dark" },
	{ name = "panel", parent = "base", shape = "box", size = { 2.6, 1.6, 0.3 }, at = { 5, 8.8, 5 }, rot = { 15, 0, 0 }, color = "hull" },
}
for i, p in { { -7, -7 }, { 7, -7 }, { -7, 7 }, { 7, 7 } } do
	table.insert(parts, { name = `float{i}`, parent = "base", shape = "cylinder", axis = "y", size = { 3, 1.6, 3 }, at = { p[1], 0.4, p[2] }, color = "metal" })
end

return { id = "chs_deepear", parts = parts }
