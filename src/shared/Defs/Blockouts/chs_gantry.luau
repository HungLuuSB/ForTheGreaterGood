--!strict
-- Experimental Gantry (Chaos T3 factory, footprint 7; S-209, BAR corgant):
-- a huge raised assembly platform whose floor is two armored doors split
-- along a zigzag seam (the Juggernaut rises through it), walled at the back
-- by a stepped bunker with a central pod and on both sides by low armored
-- walls whose heavy emitter heads lean over the floor; a wide ramp down at
-- the front (-Z). Chaos reads crude and exposed (M-14). Model space,
-- forward = -Z.

local PY = 4 -- the platform's top
local PZ = -3 -- the pad's centre
local WX = 23.5 -- the side walls' centre
local HX = 20.4 -- the emitter heads' x
local HY = 9.6 -- the emitter heads' height

local parts = {
	{ name = "base", shape = "box", size = { 54, 0.5, 54 }, at = { 0, 0.25, 0 }, color = "dark" },
	{ name = "platform", parent = "base", shape = "box", size = { 42, PY - 0.5, 36 }, at = { 0, (PY + 0.5) / 2, -2 }, color = "hull" },
	{ name = "doorL", parent = "base", shape = "box", size = { 15, 0.2, 28 }, at = { -7.6, PY + 0.1, PZ }, color = "metal" },
	{ name = "doorR", parent = "base", shape = "box", size = { 15, 0.2, 28 }, at = { 7.6, PY + 0.1, PZ }, color = "metal" },
	{ name = "seam", parent = "base", shape = "box", size = { 0.6, 0.1, 28 }, at = { 0, PY + 0.25, PZ }, color = "glass" },
	{ name = "ramp", parent = "base", shape = "wedge", size = { 22, PY - 0.5, 7 }, at = { 0, (PY + 0.5) / 2, -23.5 }, rot = { 0, 180, 0 }, color = "metal" },
	{ name = "rampHazard", parent = "base", shape = "box", size = { 22, 0.06, 0.8 }, at = { 0, 0.53, -26.8 }, color = "hazard" },
	{ name = "teamA", parent = "base", shape = "box", size = { 5, 0.1, 5 }, at = { -21, 0.55, -23 }, color = "team" },
	{ name = "teamB", parent = "base", shape = "box", size = { 5, 0.1, 5 }, at = { 21, 0.55, -23 }, color = "team" },

	-- the bunker at the back and its pod
	{ name = "bunker", parent = "base", shape = "box", size = { 42, 10, 11 }, at = { 0, 5.5, 21.5 }, color = "hull" },
	{ name = "bunkerFront", parent = "base", shape = "wedge", size = { 42, 6, 3 }, at = { 0, PY + 3, 14.5 }, color = "hull" },
	{ name = "pod", parent = "base", shape = "box", size = { 12, 6, 8 }, at = { 0, 13.5, 21 }, color = "hull" },
	{ name = "podGlass", parent = "base", shape = "box", size = { 8, 1.2, 0.1 }, at = { 0, 14, 16.95 }, color = "glass" },
	{ name = "podTeam", parent = "base", shape = "box", size = { 8, 0.12, 6 }, at = { 0, 16.56, 21 }, color = "team" },
}
for _, sx in { -1, 1 } do
	local tag = if sx < 0 then "L" else "R"
	table.insert(parts, { name = `wall{tag}`, parent = "base", shape = "box", size = { 7, 8.4, 32 }, at = { sx * WX, 4.7, -2 }, color = "hull" })
	table.insert(parts, { name = `wallTeam{tag}`, parent = "base", shape = "box", size = { 0.1, 3, 10 }, at = { sx * (WX + 3.56), 5, -2 }, color = "team" })
	table.insert(parts, { name = `backHead{tag}`, parent = "base", shape = "box", size = { 4, 3, 3.4 }, at = { sx * 7.5, 12, 15.4 }, color = "team" })
	table.insert(parts, { name = `beacon{tag}`, parent = "base", shape = "box", size = { 0.8, 0.8, 0.8 }, at = { sx * 25, 1, -25 }, color = "glass" })
end
local Z = { -14, -3, 8 }
for i, z in Z do
	table.insert(parts, { name = `headL{i}`, parent = "base", shape = "box", size = { 4, 3, 3.6 }, at = { -HX - 0.6, HY + 0.4, z }, color = "team" })
	table.insert(parts, { name = `headR{i}`, parent = "base", shape = "box", size = { 4, 3, 3.6 }, at = { HX + 0.6, HY + 0.4, z }, color = "team" })
	table.insert(parts, { name = `lensL{i}`, parent = "base", shape = "box", size = { 0.1, 1.2, 1.4 }, at = { -HX + 1.45, HY + 0.4, z }, color = "glass" })
	table.insert(parts, { name = `lensR{i}`, parent = "base", shape = "box", size = { 0.1, 1.2, 1.4 }, at = { HX - 1.45, HY + 0.4, z }, color = "glass" })
end

return {
	id = "chs_gantry",
	parts = parts,
	-- nanoframe anchors (M-25, rig.md 8)
	attachments = {
		{ name = "buildpad", parent = "base", at = { 0, PY + 0.2, PZ } },
		{ name = "nano1", parent = "base", at = { -HX + 1.5, HY + 0.4, -14 } },
		{ name = "nano2", parent = "base", at = { HX - 1.5, HY + 0.4, -14 } },
		{ name = "nano3", parent = "base", at = { -HX + 1.5, HY + 0.4, -3 } },
		{ name = "nano4", parent = "base", at = { HX - 1.5, HY + 0.4, -3 } },
		{ name = "nano5", parent = "base", at = { -HX + 1.5, HY + 0.4, 8 } },
		{ name = "nano6", parent = "base", at = { HX - 1.5, HY + 0.4, 8 } },
		{ name = "nano7", parent = "base", at = { -7.5, 12, 13.6 } },
		{ name = "nano8", parent = "base", at = { 7.5, 12, 13.6 } },
	},
}
