--!strict
-- Airfield (Order, T1, footprint 5): a runway with cyan edge lights, an
-- armored hangar with a team roof, a control tower with a glass top and a
-- flat radar panel. Model space, forward = -Z (docs/contracts/rig.md).

local parts = {
	{ name = "base", shape = "box", size = { 38, 0.4, 38 }, at = { 0, 0.2, 0 }, color = "dark" },
	{ name = "runway", parent = "base", shape = "box", size = { 10, 0.2, 37 }, at = { 2, 0.5, 0 }, color = "metal" },
	{ name = "stripe", parent = "base", shape = "box", size = { 0.6, 0.06, 30 }, at = { 2, 0.63, 0 }, color = "team" },
	{ name = "hangar", parent = "base", shape = "box", size = { 12, 5, 12 }, at = { -12, 2.9, 8 }, color = "hull" },
	{ name = "hangarRoof", parent = "base", shape = "wedge", size = { 12, 1.6, 12 }, at = { -12, 6.2, 8 }, color = "hull" },
	{ name = "hangarTeam", parent = "base", shape = "box", size = { 9, 0.12, 6 }, at = { -12, 5.47, 11.2 }, color = "team" },
	{ name = "hangarDoor", parent = "base", shape = "box", size = { 9, 4, 0.3 }, at = { -12, 2.4, 1.9 }, color = "dark" },
	{ name = "tower", parent = "base", shape = "box", size = { 4, 7, 4 }, at = { 13, 3.9, 12 }, color = "hull" },
	{ name = "towerGlass", parent = "base", shape = "box", size = { 4.4, 1.4, 4.4 }, at = { 13, 8.1, 12 }, color = "glass" },
	{ name = "towerRoof", parent = "base", shape = "box", size = { 5, 0.4, 5 }, at = { 13, 9.0, 12 }, color = "hull" },
	{ name = "radarPanel", parent = "base", shape = "box", size = { 3, 2, 0.3 }, at = { 13, 10.4, 12 }, rot = { 20, 0, 0 }, color = "dark", anim = { motion = "turn", axis = { 0, 1, 0 } } },
	{ name = "padA", parent = "base", shape = "box", size = { 7, 0.15, 7 }, at = { -12, 0.47, -9 }, color = "metal" },
	{ name = "padATeam", parent = "base", shape = "box", size = { 4, 0.06, 4 }, at = { -12, 0.58, -9 }, color = "team" },
}
for i = 0, 5 do
	local z = -16 + i * 6.4
	table.insert(parts, { name = `lightL{i}`, parent = "base", shape = "box", size = { 0.4, 0.3, 0.4 }, at = { -3.4, 0.55, z }, color = "glass" })
	table.insert(parts, { name = `lightR{i}`, parent = "base", shape = "box", size = { 0.4, 0.3, 0.4 }, at = { 7.4, 0.55, z }, color = "glass" })
end

return {
	id = "ord_airfield",
	parts = parts,
	-- nanoframe anchors (M-25, rig.md 8)
	attachments = {
		{ name = "buildpad", parent = "base", at = { -12, 0.55, -9 } },
		{ name = "nano1", parent = "base", at = { -16.75, 5.4, 1.75 } },
		{ name = "nano2", parent = "base", at = { -7.25, 5.4, 1.75 } },
		{ name = "nano3", parent = "base", at = { -12, 5.5, 1.75 } },
	},
}
