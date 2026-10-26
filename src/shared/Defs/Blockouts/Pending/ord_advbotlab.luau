--!strict
-- Advanced Bot Lab (Order bot factory, T2, footprint 5; S-181): the Bot
-- Lab's layout grown for heavy bots: a taller armored hall with two team
-- roof panels, a radar and a control cab, and in front a heavy portal gantry
-- (pillars with buttresses, a double beam) over a big lit pad, four
-- emitters. Order reads clean and heavy (M-14). Model space, forward = -Z.

local PZ = -8 -- the pad's centre
local GY = 17.4 -- the gantry beam's height

local parts = {
	{ name = "base", shape = "box", size = { 38, 0.6, 38 }, at = { 0, 0.3, 0 }, color = "dark" },
	{ name = "pad", parent = "base", shape = "box", size = { 18, 0.2, 16 }, at = { 0, 0.7, PZ }, color = "metal" },
	{ name = "padRing", parent = "base", shape = "cylinder", axis = "y", size = { 12, 0.1, 12 }, at = { 0, 0.85, PZ }, color = "glass" },
	{ name = "padHazard", parent = "base", shape = "box", size = { 18, 0.06, 0.9 }, at = { 0, 0.83, PZ - 8.5 }, color = "hazard" },

	-- the hall
	{ name = "hall", parent = "base", shape = "box", size = { 34, 12, 17 }, at = { 0, 6.6, 9.5 }, color = "hull" },
	{ name = "hallFront", parent = "base", shape = "wedge", size = { 34, 12, 2 }, at = { 0, 6.6, 0 }, color = "hull" },
	{ name = "door", parent = "base", shape = "box", size = { 14, 9, 0.3 }, at = { 0, 5.1, -0.4 }, color = "dark" },
	{ name = "doorLight", parent = "base", shape = "box", size = { 14, 0.35, 0.12 }, at = { 0, 9.9, -0.6 }, color = "glass" },
	{ name = "roof", parent = "base", shape = "box", size = { 34.4, 1, 17.4 }, at = { 0, 13.1, 9.5 }, color = "dark" },
	{ name = "roofTeamL", parent = "base", shape = "box", size = { 11, 0.12, 11 }, at = { -8.5, 13.66, 10 }, color = "team" },
	{ name = "roofTeamR", parent = "base", shape = "box", size = { 11, 0.12, 11 }, at = { 8.5, 13.66, 10 }, color = "team" },
	{ name = "cab", parent = "base", shape = "box", size = { 6, 4.4, 5 }, at = { 12, 15.8, 14.5 }, color = "hull" },
	{ name = "cabGlass", parent = "base", shape = "box", size = { 5.4, 1.2, 0.1 }, at = { 12, 16.6, 11.95 }, color = "glass" },
	{ name = "radarMast", parent = "base", shape = "box", size = { 0.6, 6, 0.6 }, at = { -13, 16.6, 15 }, color = "dark" },
	{ name = "radar", parent = "base", shape = "box", size = { 4, 1.4, 0.3 }, at = { -13, 20, 15 }, color = "metal", anim = { motion = "turn", axis = { 0, 1, 0 } } },
	{ name = "buttressL", parent = "base", shape = "wedge", size = { 8, 8, 3 }, at = { -18.3, 4.6, 9.5 }, rot = { 0, 90, 0 }, color = "hull" },
	{ name = "buttressR", parent = "base", shape = "wedge", size = { 8, 8, 3 }, at = { 18.3, 4.6, 9.5 }, rot = { 0, -90, 0 }, color = "hull" },

	-- the portal gantry over the pad
	{ name = "beam", parent = "base", shape = "box", size = { 26, 2.4, 3 }, at = { 0, GY + 1.2, PZ }, color = "hull" },
	{ name = "beam2", parent = "base", shape = "box", size = { 26, 1.6, 1.6 }, at = { 0, GY + 1.6, PZ + 3.2 }, color = "dark" },
	{ name = "beamLight", parent = "base", shape = "box", size = { 20, 0.25, 0.1 }, at = { 0, GY + 1.2, PZ - 1.55 }, color = "glass" },
	{ name = "beamTie", parent = "base", shape = "box", size = { 2, 1.6, 7 }, at = { 0, GY + 1, PZ + 6 }, color = "dark" },
}
for _, sx in { -1, 1 } do
	local tag = if sx < 0 then "L" else "R"
	table.insert(parts, { name = `pillar{tag}`, parent = "base", shape = "box", size = { 2.6, GY - 0.6, 2.8 }, at = { sx * 11.5, (GY - 0.6) / 2 + 0.6, PZ }, color = "hull" })
	table.insert(parts, { name = `pillarFoot{tag}`, parent = "base", shape = "wedge", size = { 2.8, 4, 2.4 }, at = { sx * 11.5, 2.6, PZ - 2.6 }, color = "hull" })
	table.insert(parts, { name = `pillarTeam{tag}`, parent = "base", shape = "box", size = { 0.08, 5, 1.8 }, at = { sx * 12.84, 8, PZ }, color = "team" })
	table.insert(parts, { name = `beacon{tag}`, parent = "base", shape = "box", size = { 0.7, 0.7, 0.7 }, at = { sx * 18, 1, -18 }, color = "glass" })
end
for i, x in { -9, -3, 3, 9 } do
	table.insert(parts, { name = `emitter{i}`, parent = "base", shape = "box", size = { 1.2, 1, 1.2 }, at = { x, GY - 0.5, PZ }, color = "metal" })
end

return {
	id = "ord_advbotlab",
	parts = parts,
	-- nanoframe anchors (M-25, rig.md 8)
	attachments = {
		{ name = "buildpad", parent = "base", at = { 0, 0.8, PZ } },
		{ name = "nano1", parent = "base", at = { -9, GY - 1.1, PZ } },
		{ name = "nano2", parent = "base", at = { 9, GY - 1.1, PZ } },
		{ name = "nano3", parent = "base", at = { -3, GY - 1.1, PZ } },
		{ name = "nano4", parent = "base", at = { 3, GY - 1.1, PZ } },
	},
}
