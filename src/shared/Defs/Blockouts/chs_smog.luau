--!strict
-- Smog (Chaos jammer, T1, footprint 1): a low skid with a short lattice mast
-- and one ring of glowing emitter rods; the T2 Blackout is the tall mast
-- with three rings. Team plate on the skid. Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 4.6, 0.5, 4.6 }, at = { 0, 0.25, 0 }, color = "dark" },
	{ name = "team", parent = "base", shape = "box", size = { 3.4, 0.08, 1 }, at = { 0, 0.54, 1.6 }, color = "team" },
	{ name = "spine", parent = "base", shape = "cylinder", axis = "y", size = { 0.6, 5, 0.6 }, at = { 0, 3, 0 }, color = "hull", anim = { motion = "spin", axis = { 0, 1, 0 } } },
}
for i, p in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
	table.insert(parts, { name = `leg{i}`, parent = "base", shape = "box", size = { 0.2, 4, 0.2 }, at = { p[1] * 0.5, 2.3, p[2] * 0.5 }, rot = { p[2] > 0 and -6 or 6, 0, p[1] > 0 and 6 or -6 }, color = "dark" })
end
for k = 0, 3 do
	local a = k * 90 + 45
	local rad = math.rad(a)
	table.insert(parts, { name = `rod{k}`, parent = "spine", shape = "box", size = { 0.18, 0.18, 1.4 }, at = { math.sin(rad) * 0.9, 4.6, math.cos(rad) * 0.9 }, rot = { 0, a, 0 }, color = "glass" })
end

return { id = "chs_smog", parts = parts }
