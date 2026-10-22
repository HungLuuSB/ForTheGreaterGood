--!strict
-- Advanced Aerodrome (Chaos, T2, footprint 5): a wide runway with orange
-- edge lights, two open roof-on-posts hangars, fuel tanks, a tall lattice
-- mast with a radar panel. Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 38, 0.4, 38 }, at = { 0, 0.2, 0 }, color = "dark" },
	{ name = "runway", parent = "base", shape = "box", size = { 11, 0.2, 37 }, at = { 5, 0.5, 0 }, color = "metal" },
	{ name = "stripe", parent = "base", shape = "box", size = { 0.8, 0.06, 30 }, at = { 5, 0.63, 0 }, color = "team" },
	{ name = "tankA", parent = "base", shape = "cylinder", axis = "y", size = { 3.4, 3, 3.4 }, at = { 15.5, 1.9, -14 }, color = "metal" },
	{ name = "tankB", parent = "base", shape = "cylinder", axis = "y", size = { 3.4, 3, 3.4 }, at = { 15.5, 1.9, -9.6 }, color = "metal" },
	{ name = "mast", parent = "base", shape = "box", size = { 0.7, 14, 0.7 }, at = { 15.5, 7.4, 14 }, color = "dark" },
	{ name = "mastBraceA", parent = "base", shape = "box", size = { 0.3, 12, 0.3 }, at = { 16.8, 6.4, 14 }, rot = { 0, 0, 7 }, color = "dark" },
	{ name = "radarPanel", parent = "base", shape = "box", size = { 3.6, 2.4, 0.3 }, at = { 15.5, 15, 14 }, rot = { 20, 0, 0 }, color = "dark", anim = { motion = "turn", axis = { 0, 1, 0 } } },
	{ name = "beacon", parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { 15.5, 16.6, 14 }, color = "glass" },
	-- T2 signature (T1 vs T2 check, 2026-10-22): a ski-jump ramp at the
	-- runway's end and a blast deflector at its start
	{ name = "skiJump", parent = "base", shape = "wedge", size = { 11, 3.2, 6.5 }, at = { 5, 2.2, -15.2 }, rot = { 0, 180, 0 }, color = "team" },
	{ name = "deflector", parent = "base", shape = "box", size = { 11, 3.4, 0.4 }, at = { 5, 2.0, 18.2 }, rot = { -35, 0, 0 }, color = "dark" },
}
for h, z in { -9, 8 } do
	table.insert(parts, { name = `roof{h}`, parent = "base", shape = "box", size = { 11, 0.4, 12 }, at = { -12.5, 5.6, z }, color = "hull" })
	table.insert(parts, { name = `roofTeam{h}`, parent = "base", shape = "box", size = { 7, 0.1, 6 }, at = { -12.5, 5.85, z }, color = "team" })
	for i, p in { { -17.6, z - 5.6 }, { -7.4, z - 5.6 }, { -17.6, z + 5.6 }, { -7.4, z + 5.6 } } do
		table.insert(parts, { name = `post{h}{i}`, parent = "base", shape = "box", size = { 0.5, 5.4, 0.5 }, at = { p[1], 2.9, p[2] }, color = "dark" })
	end
end
for i = 0, 5 do
	local z = -16 + i * 6.4
	table.insert(parts, { name = `lightL{i}`, parent = "base", shape = "box", size = { 0.4, 0.3, 0.4 }, at = { -0.9, 0.55, z }, color = "glass" })
	table.insert(parts, { name = `lightR{i}`, parent = "base", shape = "box", size = { 0.4, 0.3, 0.4 }, at = { 10.9, 0.55, z }, color = "glass" })
end

-- footprint 5 -> 6 (size scale, M-26 / S-104): scaled until the redesign lands
return require("./Scale").scaled({
	id = "chs_advairfield",
	parts = parts,
	-- nanoframe anchors (M-25, rig.md 8)
	attachments = {
		{ name = "buildpad", parent = "base", at = { -12.5, 0.4, -9 } },
		{ name = "nano1", parent = "base", at = { -15.5, 5.35, -9 } },
		{ name = "nano2", parent = "base", at = { -9.5, 5.35, -9 } },
	},
}, 1.2)
