--!strict
-- All-Seer (Chaos long-range radar, T2, footprint 3): a tall open lattice
-- mast with braces on a pad, a very wide flat array (visual piece `radar`)
-- with a team band, and a big orange "eye" under it.
-- Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "cylinder", axis = "y", size = { 18, 0.8, 18 }, at = { 0, 0.4, 0 }, color = "dark" },
	{ name = "teamA", parent = "base", shape = "box", size = { 4, 0.1, 4 }, at = { -5.5, 0.85, -5.5 }, color = "team" },
	{ name = "teamB", parent = "base", shape = "box", size = { 4, 0.1, 4 }, at = { 5.5, 0.85, 5.5 }, color = "team" },
	{ name = "eye", parent = "base", shape = "ball", size = { 2.4, 2.4, 2.4 }, at = { 0, 13.4, -1.6 }, color = "glass" },
	{ name = "radar", parent = "base", shape = "box", size = { 12, 4.6, 0.5 }, at = { 0, 17.6, 0 }, rot = { 15, 0, 0 }, pivot = { 0, 15.4, 0 }, color = "hull", anim = { motion = "turn", axis = { 0, 1, 0 } } },
	{ name = "radarTeam", parent = "radar", shape = "box", size = { 11, 0.6, 0.1 }, at = { 0, 19.55, 0.75 }, rot = { 15, 0, 0 }, color = "team" },
}
for i, p in { { -2.6, -2.6 }, { 2.6, -2.6 }, { -2.6, 2.6 }, { 2.6, 2.6 } } do
	table.insert(parts, { name = `leg{i}`, parent = "base", shape = "box", size = { 0.5, 15, 0.5 }, at = { p[1] * 0.7, 8, p[2] * 0.7 }, rot = { p[2] > 0 and -5 or 5, 0, p[1] > 0 and 5 or -5 }, color = "dark" })
end
for i, y in { 4, 8, 12 } do
	local w = 4.6 - i * 0.6
	table.insert(parts, { name = `braceF{i}`, parent = "base", shape = "box", size = { w, 0.3, 0.3 }, at = { 0, y, -w / 2 + 0.3 }, color = "dark" })
	table.insert(parts, { name = `braceB{i}`, parent = "base", shape = "box", size = { w, 0.3, 0.3 }, at = { 0, y, w / 2 - 0.3 }, color = "dark" })
end

return { id = "chs_allseer", visualPieces = { "radar" }, parts = parts }
