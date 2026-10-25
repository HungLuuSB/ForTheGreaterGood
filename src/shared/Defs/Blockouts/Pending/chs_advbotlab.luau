--!strict
-- Advanced Bot Pit (Chaos bot factory, T2, footprint 5; S-181): the Bot
-- Pit grown for heavy bots: a bigger pit walled by tall scrap plates with
-- spikes, open at the front with a wide ramp; a lattice tower crane at the
-- back whose long jib reaches over the pit (its trolley sprays), two lamp
-- masts that spray from the sides, furnace stacks with glowing mouths.
-- Chaos reads crude and exposed (M-14). Model space, forward = -Z.

local PZ = -3 -- the pit's centre
local JY = 21 -- the tower crane's jib height

local parts = {
	{ name = "base", shape = "box", size = { 38, 0.5, 38 }, at = { 0, 0.25, 0 }, color = "dark" },
	{ name = "pitFloor", parent = "base", shape = "cylinder", axis = "y", size = { 23, 0.3, 23 }, at = { 0, 0.65, PZ }, color = "metal" },
	{ name = "pitGrate", parent = "base", shape = "cylinder", axis = "y", size = { 10, 0.1, 10 }, at = { 0, 0.85, PZ }, color = "glass" },
	{ name = "ramp", parent = "base", shape = "wedge", size = { 10, 1.4, 5 }, at = { 0, 1.2, PZ - 14 }, color = "metal" },
	{ name = "rampHazard", parent = "base", shape = "box", size = { 10, 0.06, 0.7 }, at = { 0, 0.53, PZ - 16.6 }, color = "hazard" },
	{ name = "teamA", parent = "base", shape = "box", size = { 6, 0.1, 6 }, at = { -14, 0.55, -14 }, color = "team" },
	{ name = "teamB", parent = "base", shape = "box", size = { 6, 0.1, 6 }, at = { 14, 0.55, -14 }, color = "team" },

	-- the tower crane at the back
	{ name = "tower", parent = "base", shape = "box", size = { 3, JY, 3 }, at = { 0, JY / 2 + 0.5, 13.5 }, color = "dark" },
	{ name = "towerTeam", parent = "base", shape = "box", size = { 2, 4, 0.1 }, at = { 0, 9, 11.95 }, color = "team" },
	{ name = "cab", parent = "base", shape = "box", size = { 3.4, 2.6, 3.4 }, at = { 2.6, JY - 1, 13.5 }, color = "hull" },
	{ name = "cabGlass", parent = "base", shape = "box", size = { 3, 0.8, 0.1 }, at = { 2.6, JY - 0.6, 11.75 }, color = "glass" },
	{ name = "jib", parent = "base", shape = "box", size = { 1.6, 1.6, 24 }, at = { 0, JY + 0.8, 3.5 }, color = "metal" },
	{ name = "counterJib", parent = "base", shape = "box", size = { 1.6, 1.4, 6 }, at = { 0, JY + 0.8, 18 }, color = "metal" },
	{ name = "counterweight", parent = "base", shape = "box", size = { 3, 2.4, 2.6 }, at = { 0, JY - 0.6, 19.2 }, color = "hull" },
	{ name = "trolley", parent = "base", shape = "box", size = { 2, 1.6, 2 }, at = { 0, JY - 0.8, PZ }, color = "dark" },
	{ name = "lampTop", parent = "base", shape = "box", size = { 0.7, 0.7, 0.7 }, at = { 0, JY + 2, 13.5 }, color = "glass" },
}
for i = 0, 11 do -- tall scrap walls round the pit, open at the front
	local a = i * 30
	if a < 150 or a > 210 then
		local r = math.rad(a)
		table.insert(parts, { name = `wall{i}`, parent = "base", shape = "box", size = { 6.4, 3.4 + (i % 2) * 1.2, 1 }, at = { math.sin(r) * 12.4, 2.2 + (i % 2) * 0.6, PZ + math.cos(r) * 12.4 }, rot = { 0, a, (i % 3 - 1) * 4 }, color = if i % 2 == 0 then "metal" else "hull" })
		table.insert(parts, { name = `spike{i}`, parent = "base", shape = "wedge", size = { 0.6, 1.8, 1 }, at = { math.sin(r) * 12.4, 4.7 + (i % 2) * 1.2, PZ + math.cos(r) * 12.4 }, rot = { 0, a, 0 }, color = "metal" })
	end
end
for _, sx in { -1, 1 } do -- lamp masts either side of the pit, and furnace stacks
	local tag = if sx < 0 then "L" else "R"
	table.insert(parts, { name = `lampMast{tag}`, parent = "base", shape = "box", size = { 1, 13, 1 }, at = { sx * 14.5, 7, PZ }, color = "dark" })
	table.insert(parts, { name = `lampArm{tag}`, parent = "base", shape = "box", size = { 5, 0.6, 0.6 }, at = { sx * 12.3, 13.2, PZ }, color = "metal" })
	table.insert(parts, { name = `lamp{tag}`, parent = "base", shape = "box", size = { 1, 0.8, 1 }, at = { sx * 10.2, 12.6, PZ }, color = "glass" })
	table.insert(parts, { name = `stack{tag}`, parent = "base", shape = "cylinder", axis = "y", size = { 3.2, 12, 3.2 }, at = { sx * 13.5, 6.5, 14.5 }, color = "hull" })
	table.insert(parts, { name = `stackGlow{tag}`, parent = "base", shape = "cylinder", axis = "y", size = { 2.4, 0.2, 2.4 }, at = { sx * 13.5, 12.6, 14.5 }, color = "glass" })
end

return {
	id = "chs_advbotlab",
	parts = parts,
	-- nanoframe anchors (M-25, rig.md 8)
	attachments = {
		{ name = "buildpad", parent = "base", at = { 0, 0.8, PZ } },
		{ name = "nano1", parent = "base", at = { 0, JY - 1.7, PZ } },
		{ name = "nano2", parent = "base", at = { -10.2, 12.1, PZ } },
		{ name = "nano3", parent = "base", at = { 10.2, 12.1, PZ } },
	},
}
