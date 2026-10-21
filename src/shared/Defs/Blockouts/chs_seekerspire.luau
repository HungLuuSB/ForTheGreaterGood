--!strict
-- Seeker Spire (Chaos fire-control radar, T2, footprint 2): a tall narrow
-- lattice spire with a flat panel near the top (visual piece `radar`) and an
-- orange eye; cheaper and lighter than the Tribunal. Model space,
-- forward = -Z.

local parts = {
	{ name = "base", shape = "cylinder", axis = "y", size = { 12, 0.8, 12 }, at = { 0, 0.4, 0 }, color = "dark" },
	{ name = "teamA", parent = "base", shape = "box", size = { 3, 0.1, 3 }, at = { -3.6, 0.85, 3 }, color = "team" },
	{ name = "eye", parent = "base", shape = "ball", size = { 1.4, 1.4, 1.4 }, at = { 0, 10.5, -1 }, color = "glass" },
	{ name = "radar", parent = "base", shape = "box", size = { 4.4, 3.4, 0.4 }, at = { 0, 13.4, 0 }, pivot = { 0, 11.6, 0 }, color = "hull" },
	{ name = "radarTeam", parent = "radar", shape = "box", size = { 4, 0.4, 0.08 }, at = { 0, 14.7, 0.24 }, color = "team" },
}
for i, p in { { -1.6, -1.6 }, { 1.6, -1.6 }, { -1.6, 1.6 }, { 1.6, 1.6 } } do
	table.insert(parts, { name = `leg{i}`, parent = "base", shape = "box", size = { 0.35, 11.4, 0.35 }, at = { p[1] * 0.6, 6.1, p[2] * 0.6 }, rot = { p[2] > 0 and -5 or 5, 0, p[1] > 0 and 5 or -5 }, color = "dark" })
end
for i, y in { 3.5, 7.5 } do
	table.insert(parts, { name = `brace{i}`, parent = "base", shape = "box", size = { 2.4 - i * 0.4, 0.25, 0.25 }, at = { 0, y, -0.9 }, color = "dark" })
end

return { id = "chs_seekerspire", visualPieces = { "radar" }, parts = parts }
