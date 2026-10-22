--!strict
-- Aerodrome (Chaos, T1, footprint 5): a runway with orange edge lights, an
-- open arched hangar frame, round fuel tanks and a lattice control mast with
-- a flat radar panel. Model space, forward = -Z (docs/contracts/rig.md).

local parts = {
	{ name = "base", shape = "box", size = { 38, 0.4, 38 }, at = { 0, 0.2, 0 }, color = "dark" },
	{ name = "runway", parent = "base", shape = "box", size = { 9, 0.2, 37 }, at = { 3, 0.5, 0 }, color = "metal" },
	{ name = "stripe", parent = "base", shape = "box", size = { 0.6, 0.06, 30 }, at = { 3, 0.63, 0 }, color = "team" },
	{ name = "hangarRoof", parent = "base", shape = "box", size = { 12, 0.4, 12 }, at = { -12, 5.4, 8 }, color = "hull" },
	{ name = "hangarTeam", parent = "base", shape = "box", size = { 8, 0.1, 6 }, at = { -12, 5.65, 8 }, color = "team" },
	{ name = "hangarBack", parent = "base", shape = "box", size = { 12, 5, 0.4 }, at = { -12, 2.9, 13.8 }, color = "hull" },
	{ name = "tankA", parent = "base", shape = "cylinder", axis = "y", size = { 3.4, 3, 3.4 }, at = { 13, 1.9, -12 }, color = "metal" },
	{ name = "tankB", parent = "base", shape = "cylinder", axis = "y", size = { 3.4, 3, 3.4 }, at = { 13, 1.9, -7.6 }, color = "metal" },
	{ name = "mast", parent = "base", shape = "box", size = { 0.6, 10, 0.6 }, at = { 13, 5.4, 10 }, color = "dark" },
	{ name = "mastBrace", parent = "base", shape = "box", size = { 0.3, 9, 0.3 }, at = { 14.2, 4.9, 10 }, rot = { 0, 0, 8 }, color = "dark" },
	{ name = "radarPanel", parent = "base", shape = "box", size = { 3, 2, 0.3 }, at = { 13, 11, 10 }, rot = { 20, 0, 0 }, color = "dark" },
	{ name = "beacon", parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { 13, 12.3, 10 }, color = "glass" },
}
for i, p in { { -17.6, 2.4 }, { -6.4, 2.4 }, { -17.6, 13.6 }, { -6.4, 13.6 } } do
	table.insert(parts, { name = `post{i}`, parent = "base", shape = "box", size = { 0.5, 5.2, 0.5 }, at = { p[1], 2.8, p[2] }, color = "dark" })
end
for i = 0, 5 do
	local z = -16 + i * 6.4
	table.insert(parts, { name = `lightL{i}`, parent = "base", shape = "box", size = { 0.4, 0.3, 0.4 }, at = { -1.8, 0.55, z }, color = "glass" })
	table.insert(parts, { name = `lightR{i}`, parent = "base", shape = "box", size = { 0.4, 0.3, 0.4 }, at = { 7.8, 0.55, z }, color = "glass" })
end

return {
	id = "chs_airfield",
	parts = parts,
	-- nanoframe anchors (M-25, rig.md 8)
	attachments = {
		{ name = "buildpad", parent = "base", at = { -12, 0.4, 7.5 } },
		{ name = "nano1", parent = "base", at = { -16, 5.05, 8 } },
		{ name = "nano2", parent = "base", at = { -12, 5.05, 8 } },
		{ name = "nano3", parent = "base", at = { -8, 5.05, 8 } },
	},
}
