--!strict
-- Advanced Airfield (Order, T2, footprint 5): a wide runway with cyan edge
-- lights, two armored hangars with team roofs, a tall control tower with a
-- glass top and a radar panel. Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 38, 0.4, 38 }, at = { 0, 0.2, 0 }, color = "dark" },
	{ name = "runway", parent = "base", shape = "box", size = { 12, 0.2, 37 }, at = { 5, 0.5, 0 }, color = "metal" },
	{ name = "stripe", parent = "base", shape = "box", size = { 0.8, 0.06, 30 }, at = { 5, 0.63, 0 }, color = "team" },
	{ name = "tower", parent = "base", shape = "box", size = { 4, 10, 4 }, at = { 15.5, 5.4, 15 }, color = "hull" },
	{ name = "towerGlass", parent = "base", shape = "box", size = { 4.6, 1.6, 4.6 }, at = { 15.5, 11.2, 15 }, color = "glass" },
	{ name = "towerRoof", parent = "base", shape = "box", size = { 5.2, 0.5, 5.2 }, at = { 15.5, 12.25, 15 }, color = "hull" },
	{ name = "radarPanel", parent = "base", shape = "box", size = { 3.4, 2.2, 0.3 }, at = { 15.5, 13.8, 15 }, rot = { 20, 0, 0 }, color = "dark" },
	-- T2 signature (T1 vs T2 check, 2026-10-22): a big approach-radar radome
	{ name = "radomeBlock", parent = "base", shape = "box", size = { 6, 4, 6 }, at = { 15.5, 2.4, -13 }, color = "hull" },
	{ name = "radomeTeam", parent = "base", shape = "box", size = { 5.5, 0.6, 0.06 }, at = { 15.5, 3.4, -15.73 }, color = "team" },
	{ name = "radome", parent = "base", shape = "ball", size = { 9, 9, 9 }, at = { 15.5, 8.4, -13 }, color = "hull" },
	{ name = "radomeLight", parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { 15.5, 13.1, -13 }, color = "glass" },
}
for i, z in { -9, 8 } do
	table.insert(parts, { name = `hangar{i}`, parent = "base", shape = "box", size = { 11, 5.5, 13 }, at = { -12.5, 3.15, z }, color = "hull" })
	table.insert(parts, { name = `hangarRoof{i}`, parent = "base", shape = "wedge", size = { 11, 1.6, 13 }, at = { -12.5, 6.7, z }, rot = { 0, -90, 0 }, color = "hull" })
	table.insert(parts, { name = `hangarTeam{i}`, parent = "base", shape = "box", size = { 5, 0.12, 9 }, at = { -15, 5.97, z }, color = "team" })
	table.insert(parts, { name = `hangarDoor{i}`, parent = "base", shape = "box", size = { 0.3, 4.4, 10 }, at = { -6.9, 2.6, z }, color = "dark" })
end
for i = 0, 5 do
	local z = -16 + i * 6.4
	table.insert(parts, { name = `lightL{i}`, parent = "base", shape = "box", size = { 0.4, 0.3, 0.4 }, at = { -1.4, 0.55, z }, color = "glass" })
	table.insert(parts, { name = `lightR{i}`, parent = "base", shape = "box", size = { 0.4, 0.3, 0.4 }, at = { 11.4, 0.55, z }, color = "glass" })
end

-- footprint 5 -> 6 (size scale, M-26 / S-104): scaled until the redesign lands
return require("./Scale").scaled({
	id = "ord_advairfield",
	parts = parts,
	-- nanoframe anchors (M-25, rig.md 8)
	attachments = {
		{ name = "buildpad", parent = "base", at = { 3, 0.6, -9 } },
		{ name = "nano1", parent = "base", at = { -6.7, 4.7, -13.5 } },
		{ name = "nano2", parent = "base", at = { -6.7, 4.7, -4.5 } },
	},
}, 1.169)
