--!strict
-- Vehicle Foundry (Chaos factory, T1, footprint 3): a half-open works: a
-- closed shed on the left, an open steel gantry bay with a crane beam on the
-- right, round tanks at the back, team plates on the shed roof and apron,
-- orange lights. Chaos reads light and exposed (M-14).
-- Model space, forward = -Z (docs/contracts/rig.md).

local parts = {
	{ name = "base", shape = "box", size = { 22, 0.5, 22 }, at = { 0, 0.25, 0 }, color = "dark" },
	{ name = "shed", parent = "base", shape = "box", size = { 8, 5, 14 }, at = { -6.5, 3, 2 }, color = "hull" },
	{ name = "shedRoof", parent = "base", shape = "wedge", size = { 8, 1.4, 14 }, at = { -6.5, 6.2, 2 }, rot = { 0, 90, 0 }, color = "hull" },
	{ name = "shedTeam", parent = "base", shape = "box", size = { 6, 0.1, 5 }, at = { -6.5, 5.55, -3 }, color = "team" },
	{ name = "apronTeam", parent = "base", shape = "box", size = { 8, 0.08, 3 }, at = { 4, 0.54, -8.5 }, color = "team" },
	{ name = "beam", parent = "base", shape = "box", size = { 11, 0.6, 0.6 }, at = { 3.5, 7, -4 }, color = "metal" },
	{ name = "beamB", parent = "base", shape = "box", size = { 11, 0.6, 0.6 }, at = { 3.5, 7, 8 }, color = "metal" },
	{ name = "crane", parent = "base", shape = "box", size = { 0.8, 0.8, 12.6 }, at = { 4, 7.4, 2 }, color = "dark" },
	{ name = "tankA", parent = "base", shape = "cylinder", axis = "y", size = { 3, 5, 3 }, at = { 7, 2.75, 9 }, color = "metal" },
	{ name = "tankB", parent = "base", shape = "cylinder", axis = "y", size = { 2.4, 4, 2.4 }, at = { 3.4, 2.25, 9.4 }, color = "metal" },
	{ name = "lightA", parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { 9, 7.5, -4 }, color = "glass" },
	{ name = "lightB", parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { -2.5, 4.6, -5.1 }, color = "glass" },
}
for i, p in { { -2, -4 }, { 9, -4 }, { -2, 8 }, { 9, 8 } } do
	table.insert(parts, { name = `column{i}`, parent = "base", shape = "box", size = { 0.6, 6.6, 0.6 }, at = { p[1], 3.8, p[2] }, color = "dark" })
end

-- footprint 3 -> 4 (size scale, M-26 / S-104): scaled until the redesign lands
return require("./Scale").scaled({
	id = "chs_vehplant",
	parts = parts,
	-- nanoframe anchors (M-25, rig.md 8)
	attachments = {
		{ name = "buildpad", parent = "base", at = { 3.5, 0.55, 2 } },
		{ name = "nano1", parent = "base", at = { 4, 6.4, -0.5 } },
		{ name = "nano2", parent = "base", at = { 3.5, 6.8, -4 } },
	},
}, 1.333)
