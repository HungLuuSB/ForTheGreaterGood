--!strict
-- Hellforge (Chaos fusion plant, T2, footprint 3): a tall round furnace
-- stack ringed with glowing orange bands inside an open frame, smaller
-- tanks round it, team plates on the pad. Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "cylinder", axis = "y", size = { 21, 0.8, 21 }, at = { 0, 0.4, 0 }, color = "dark" },
	{ name = "stack", parent = "base", shape = "cylinder", axis = "y", size = { 8, 10, 8 }, at = { 0, 5.8, 0 }, color = "hull" },
	{ name = "glowA", parent = "base", shape = "cylinder", axis = "y", size = { 8.2, 0.6, 8.2 }, at = { 0, 4, 0 }, color = "glass" },
	{ name = "glowB", parent = "base", shape = "cylinder", axis = "y", size = { 8.2, 0.6, 8.2 }, at = { 0, 7.6, 0 }, color = "glass" },
	{ name = "cap", parent = "base", shape = "cylinder", axis = "y", size = { 6, 1, 6 }, at = { 0, 11.3, 0 }, color = "metal" },
	{ name = "teamA", parent = "base", shape = "box", size = { 3.4, 0.1, 3.4 }, at = { -6.4, 0.85, -4 }, color = "team" },
	{ name = "teamB", parent = "base", shape = "box", size = { 3.4, 0.1, 3.4 }, at = { 6.4, 0.85, 4 }, color = "team" },
	{ name = "tankA", parent = "base", shape = "cylinder", axis = "y", size = { 2.6, 3.6, 2.6 }, at = { -7, 2.6, 4.5 }, color = "metal" },
	{ name = "tankB", parent = "base", shape = "cylinder", axis = "y", size = { 2.6, 3.6, 2.6 }, at = { 7, 2.6, -4.5 }, color = "metal" },
}
for i, p in { { -5.2, -5.2 }, { 5.2, -5.2 }, { -5.2, 5.2 }, { 5.2, 5.2 } } do
	table.insert(parts, { name = `post{i}`, parent = "base", shape = "box", size = { 0.6, 12, 0.6 }, at = { p[1], 6.4, p[2] }, color = "dark" })
end
for i, z in { -5.2, 5.2 } do
	table.insert(parts, { name = `rail{i}`, parent = "base", shape = "box", size = { 11, 0.5, 0.5 }, at = { 0, 12.1, z }, color = "dark" })
end

-- footprint 3 -> 4 (size scale, M-26 / S-104): scaled until the redesign lands
return require("./Scale").scaled({ id = "chs_fusion", parts = parts }, 1.333)
