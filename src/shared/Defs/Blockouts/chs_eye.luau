--!strict
-- Eye (Chaos radar tower, T1, footprint 1): an open lattice mast with braces
-- carrying a flat phased-array panel (visual piece `radar`, never a dish)
-- with a single orange "eye" sensor below it. Model space, forward = -Z
-- (docs/contracts/rig.md).

local parts = {
	{ name = "base", shape = "box", size = { 5, 0.5, 5 }, at = { 0, 0.25, 0 }, color = "dark" },
	{ name = "team", parent = "base", shape = "box", size = { 4, 0.08, 1.2 }, at = { 0, 0.54, 1.8 }, color = "team" },
	{ name = "braceA", parent = "base", shape = "box", size = { 2.4, 0.2, 0.2 }, at = { 0, 3.5, -1 }, color = "dark" },
	{ name = "braceB", parent = "base", shape = "box", size = { 2.4, 0.2, 0.2 }, at = { 0, 3.5, 1 }, color = "dark" },
	{ name = "braceC", parent = "base", shape = "box", size = { 1.8, 0.2, 0.2 }, at = { 0, 6.5, -0.7 }, color = "dark" },
	{ name = "eye", parent = "base", shape = "ball", size = { 1.1, 1.1, 1.1 }, at = { 0, 7.6, -0.9 }, color = "glass" },
	{ name = "radar", parent = "base", shape = "box", size = { 4.8, 2.4, 0.3 }, at = { 0, 9.8, 0 }, rot = { 15, 0, 0 }, pivot = { 0, 8.6, 0 }, color = "hull", anim = { motion = "turn", axis = { 0, 1, 0 } } },
	{ name = "radarTeam", parent = "radar", shape = "box", size = { 4.2, 0.4, 0.08 }, at = { 0, 10.85, 0.47 }, rot = { 15, 0, 0 }, color = "team" },
}
for i, p in { { -1.3, -1.3 }, { 1.3, -1.3 }, { -1.3, 1.3 }, { 1.3, 1.3 } } do
	table.insert(parts, { name = `leg{i}`, parent = "base", shape = "box", size = { 0.25, 8.4, 0.25 }, at = { p[1] * 0.7, 4.6, p[2] * 0.7 }, rot = { p[2] > 0 and -5 or 5, 0, p[1] > 0 and 5 or -5 }, color = "dark" })
end

return { id = "chs_eye", visualPieces = { "radar" }, parts = parts }
