--!strict
-- Excavator (Chaos extractor, T1, footprint 1): an open four-leg derrick over
-- a drill shaft, a small engine housing beside it, a team plate on the
-- platform, an orange light at the top. Model space, forward = -Z
-- (docs/contracts/rig.md).

local parts = {
	{ name = "base", shape = "box", size = { 6.6, 0.4, 6.6 }, at = { 0, 0.2, 0 }, color = "dark" },
	{ name = "platform", parent = "base", shape = "box", size = { 4.4, 0.4, 4.4 }, at = { 0, 0.6, 0 }, color = "hull" },
	{ name = "team", parent = "base", shape = "box", size = { 3.2, 0.08, 1.2 }, at = { 0, 0.84, -1.5 }, color = "team" },
	{ name = "drill", parent = "base", shape = "cylinder", axis = "y", size = { 1.2, 5, 1.2 }, at = { 0, 3.3, 0 }, color = "metal" },
	{ name = "head", parent = "base", shape = "box", size = { 1.8, 0.8, 1.8 }, at = { 0, 6.4, 0 }, color = "hull" },
	{ name = "light", parent = "base", shape = "box", size = { 0.4, 0.4, 0.4 }, at = { 0, 7.0, 0 }, color = "glass" },
	{ name = "housing", parent = "base", shape = "box", size = { 1.8, 1.6, 2.4 }, at = { 2.3, 1.6, 1.8 }, color = "hull" },
}
for i, p in { { -1.8, -1.8 }, { 1.8, -1.8 }, { -1.8, 1.8 }, { 1.8, 1.8 } } do
	table.insert(parts, { name = `leg{i}`, parent = "base", shape = "box", size = { 0.3, 6.2, 0.3 }, at = { p[1] * 0.75, 3.7, p[2] * 0.75 }, rot = { p[2] > 0 and -8 or 8, 0, p[1] > 0 and 8 or -8 }, color = "dark" })
end

return { id = "chs_extractor", parts = parts }
