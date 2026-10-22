--!strict
-- Blackout (Chaos jammer tower, T2, footprint 1): an open lattice mast with
-- three rings of orange emitter rods sticking out and a team band.
-- Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 5.6, 0.6, 5.6 }, at = { 0, 0.3, 0 }, color = "dark" },
	{ name = "team", parent = "base", shape = "box", size = { 4.4, 0.08, 1.2 }, at = { 0, 0.64, 2 }, color = "team" },
	{ name = "spine", parent = "base", shape = "cylinder", axis = "y", size = { 0.8, 11, 0.8 }, at = { 0, 6, 0 }, color = "hull" },
}
for i, p in { { -1.2, -1.2 }, { 1.2, -1.2 }, { -1.2, 1.2 }, { 1.2, 1.2 } } do
	table.insert(parts, { name = `leg{i}`, parent = "base", shape = "box", size = { 0.25, 9, 0.25 }, at = { p[1] * 0.6, 5, p[2] * 0.6 }, rot = { p[2] > 0 and -5 or 5, 0, p[1] > 0 and 5 or -5 }, color = "dark" })
end
for r, y in { 6.5, 8.5, 10.5 } do
	for k = 0, 3 do
		local a = k * 90 + r * 30
		local rad = math.rad(a)
		table.insert(parts, { name = `rod{r}{k}`, parent = "base", shape = "box", size = { 0.2, 0.2, 1.8 }, at = { math.sin(rad) * 1.1, y, math.cos(rad) * 1.1 }, rot = { 0, a, 0 }, color = "glass" })
	end
end

-- footprint 1 -> 2 (size scale, M-26 / S-104): scaled until the redesign lands
return require("./Scale").scaled({ id = "chs_blackout", parts = parts }, 2.0)
