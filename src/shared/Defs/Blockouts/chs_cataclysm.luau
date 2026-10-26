--!strict
-- Cataclysm (Chaos artillery emplacement, T2, footprint 3; F18 redesign
-- 2026-10-26, the user's beta feedback: "turret should stand high, proud,
-- tower above others"): a mortar tower. A pad ringed with reactive blocks, a
-- tall round pit wall with raking struts and team plates, a spiked rim, two
-- fuel tanks on the rim, and on top a rounded turret on an exposed cradle
-- with a huge fat barrel raised 40 degrees and a glowing breech band (lip
-- ~25 studs). Chaos reads crude and brutal (M-14). Model space, forward = -Z.

local GUN = 40 -- elevation, degrees
local PIVOT = { 0, 18.4, -1 } -- the cradle's trunnions

local function along(d: number): { number }
	local r = math.rad(GUN)
	return { PIVOT[1], PIVOT[2] + math.sin(r) * d, PIVOT[3] - math.cos(r) * d }
end

local parts = {
	{ name = "base", shape = "cylinder", axis = "y", size = { 22, 1.2, 22 }, at = { 0, 0.6, 0 }, color = "dark" },
	{ name = "wall", parent = "base", shape = "cylinder", axis = "y", size = { 15, 11.2, 15 }, at = { 0, 6.8, 0 }, color = "hull" },
	{ name = "rim", parent = "base", shape = "cylinder", axis = "y", size = { 16, 1, 16 }, at = { 0, 12.9, 0 }, color = "dark" },
	{ name = "pitWall", parent = "base", shape = "cylinder", axis = "y", size = { 12, 1.6, 12 }, at = { 0, 14.2, 0 }, color = "hull" },
	{ name = "plateF", parent = "base", shape = "box", size = { 4, 2.4, 0.4 }, at = { 0, 7, -7.5 }, color = "team" },
	{ name = "plateB", parent = "base", shape = "box", size = { 4, 2.4, 0.4 }, at = { 0, 7, 7.5 }, color = "team" },
	{ name = "slitL", parent = "base", shape = "box", size = { 0.1, 0.5, 3.4 }, at = { -7.52, 10, 0 }, color = "glass" },
	{ name = "slitR", parent = "base", shape = "box", size = { 0.1, 0.5, 3.4 }, at = { 7.52, 10, 0 }, color = "glass" },
	{ name = "tankA", parent = "base", shape = "cylinder", axis = "y", size = { 2.4, 4, 2.4 }, at = { 5, 15.4, 4.2 }, color = "metal" },
	{ name = "tankB", parent = "base", shape = "cylinder", axis = "y", size = { 2.4, 4, 2.4 }, at = { 2.6, 15.4, 6 }, color = "metal" },
}
for i = 0, 7 do -- reactive blocks round the pad
	local a = i * 45 + 22.5
	local r = math.rad(a)
	table.insert(parts, { name = `era{i}`, parent = "base", shape = "box", size = { 3.4, 1.6, 0.8 }, at = { math.sin(r) * 10, 2, math.cos(r) * 10 }, rot = { 0, a, 0 }, color = "metal" })
end
for i = 0, 3 do -- raking struts against the wall
	local a = i * 90 + 45
	local r = math.rad(a)
	table.insert(parts, { name = `strut{i}`, parent = "base", shape = "box", size = { 1.2, 11, 1.2 }, at = { math.sin(r) * 8.3, 6.4, math.cos(r) * 8.3 }, rot = { -10, a, 0 }, color = "metal" })
end
for i = 0, 7 do -- spikes on the rim
	local a = i * 45
	local r = math.rad(a)
	table.insert(parts, { name = `spike{i}`, parent = "base", shape = "wedge", size = { 0.6, 2.2, 1 }, at = { math.sin(r) * 7.6, 14.4, math.cos(r) * 7.6 }, rot = { 25, a + 180, 0 }, color = "metal" })
end
local tip = along(10.4)
for _, p in {
	{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 8.4, 3.2, 8.4 }, at = { 0, 16.6, 1 }, pivot = { 0, 15, 0 }, color = "hull" },
	{ name = "roofTeam", parent = "turret", shape = "box", size = { 4, 0.1, 3 }, at = { 0, 18.25, 3 }, color = "team" },
	{ name = "cradleL", parent = "turret", shape = "box", size = { 0.8, 3.4, 3.6 }, at = { -2.3, 18.6, -1 }, color = "dark" },
	{ name = "cradleR", parent = "turret", shape = "box", size = { 0.8, 3.4, 3.6 }, at = { 2.3, 18.6, -1 }, color = "dark" },
	{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 3, 3, 11 }, at = along(4.5), rot = { GUN, 0, 0 }, color = "metal" },
	{ name = "glow", parent = "turret", shape = "cylinder", axis = "z", size = { 3.3, 3.3, 0.5 }, at = along(1), rot = { GUN, 0, 0 }, color = "glass" },
	{ name = "lip", parent = "turret", shape = "cylinder", axis = "z", size = { 3.8, 3.8, 1 }, at = along(9.6), rot = { GUN, 0, 0 }, color = "dark" },
	{ name = "lampMast", parent = "turret", shape = "box", size = { 0.3, 2.4, 0.3 }, at = { -3, 19.4, 3.4 }, color = "dark" },
	{ name = "lamp", parent = "turret", shape = "box", size = { 0.7, 0.5, 0.7 }, at = { -3, 20.7, 3.4 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_cataclysm",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "turret", at = tip },
	},
}
