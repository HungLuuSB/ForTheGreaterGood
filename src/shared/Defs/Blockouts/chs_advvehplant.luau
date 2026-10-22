--!strict
-- Advanced Foundry (Chaos factory, T2, footprint 5): a long shed and two
-- open gantry bays with crane beams, a row of round tanks, team plates on
-- the shed roof and apron, orange lights. Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 38, 0.5, 38 }, at = { 0, 0.25, 0 }, color = "dark" },
	{ name = "shed", parent = "base", shape = "box", size = { 10, 7, 24 }, at = { -13, 4, 3 }, color = "hull" },
	{ name = "shedRoof", parent = "base", shape = "wedge", size = { 24, 2, 10 }, at = { -13, 8.5, 3 }, rot = { 0, 90, 0 }, color = "hull" },
	{ name = "shedTeam", parent = "base", shape = "box", size = { 8, 0.1, 8 }, at = { -13, 7.55, -6 }, color = "team" },
	{ name = "apronTeam", parent = "base", shape = "box", size = { 12, 0.08, 4 }, at = { 6, 0.54, -15 }, color = "team" },
	{ name = "beamA", parent = "base", shape = "box", size = { 26, 0.8, 0.8 }, at = { 5, 10, -8 }, color = "metal" },
	{ name = "beamB", parent = "base", shape = "box", size = { 26, 0.8, 0.8 }, at = { 5, 10, 12 }, color = "metal" },
	{ name = "craneA", parent = "base", shape = "box", size = { 1, 1, 20.8 }, at = { 0, 10.6, 2 }, color = "dark" },
	{ name = "craneB", parent = "base", shape = "box", size = { 1, 1, 20.8 }, at = { 11, 10.6, 2 }, color = "dark" },
	{ name = "lightA", parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { 17.6, 10.7, -8 }, color = "glass" },
	{ name = "lightB", parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { -7.6, 6, -9.1 }, color = "glass" },
}
for i, p in { { -7.5, -8 }, { 5, -8 }, { 17.5, -8 }, { -7.5, 12 }, { 5, 12 }, { 17.5, 12 } } do
	table.insert(parts, { name = `column{i}`, parent = "base", shape = "box", size = { 0.8, 9.4, 0.8 }, at = { p[1], 5.2, p[2] }, color = "dark" })
end
for i = 0, 3 do
	table.insert(parts, { name = `tank{i}`, parent = "base", shape = "cylinder", axis = "y", size = { 3, 5, 3 }, at = { -4 + i * 6, 2.75, 16.2 }, color = "metal" })
end

return {
	id = "chs_advvehplant",
	parts = parts,
	-- nanoframe anchors (M-25, rig.md 8)
	attachments = {
		{ name = "buildpad", parent = "base", at = { 5, 0.5, 2 } },
		{ name = "nano1", parent = "base", at = { 0, 10, 2 } },
		{ name = "nano2", parent = "base", at = { 11, 10, 2 } },
	},
}
