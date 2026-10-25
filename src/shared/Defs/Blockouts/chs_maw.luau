--!strict
-- Maw (Chaos heavy turret, T2, footprint 3; F18 redesign 2026-10-26, the
-- user's beta feedback: "turret should stand high, proud, tower above
-- others"): a scrap drum tower. A round pad ringed with reactive blocks, a
-- fat lower drum with outward spikes, four raking struts up a tall narrow
-- mid drum with amber slits and team plates, and on top (ring at RING
-- studs) a squat round turret with a very fat short gun (the "maw") glowing
-- inside its mouth, an ammo drum and a lamp mast (top ~25 studs). Chaos
-- reads crude and brutal (M-14). Model space, forward = -Z.

local RING = 16.4 -- top of the mid drum, where the turret turns
local GY = RING + 2.2 -- gun height

local parts = {
	{ name = "base", shape = "cylinder", axis = "y", size = { 22, 1.4, 22 }, at = { 0, 0.7, 0 }, color = "dark" },
	{ name = "drumLow", parent = "base", shape = "cylinder", axis = "y", size = { 15, 4.6, 15 }, at = { 0, 3.7, 0 }, color = "hull" },
	{ name = "rimLow", parent = "base", shape = "cylinder", axis = "y", size = { 15.6, 0.6, 15.6 }, at = { 0, 6.1, 0 }, color = "dark" },
	{ name = "drumMid", parent = "base", shape = "cylinder", axis = "y", size = { 9, RING - 7.6, 9 }, at = { 0, 6.4 + (RING - 7.6) / 2, 0 }, color = "hull" },
	{ name = "bandMid", parent = "base", shape = "cylinder", axis = "y", size = { 9.6, 0.8, 9.6 }, at = { 0, 10.6, 0 }, color = "dark" },
	{ name = "rimTop", parent = "base", shape = "cylinder", axis = "y", size = { 10.5, 1.2, 10.5 }, at = { 0, RING - 0.6, 0 }, color = "dark" },
	{ name = "plateF", parent = "base", shape = "box", size = { 3.4, 2, 0.4 }, at = { 0, 8.6, -4.55 }, color = "team" },
	{ name = "plateB", parent = "base", shape = "box", size = { 3.4, 2, 0.4 }, at = { 0, 8.6, 4.55 }, color = "team" },
	{ name = "slitL", parent = "base", shape = "box", size = { 0.1, 0.5, 2.6 }, at = { -4.52, RING - 3, 0 }, color = "glass" },
	{ name = "slitR", parent = "base", shape = "box", size = { 0.1, 0.5, 2.6 }, at = { 4.52, RING - 3, 0 }, color = "glass" },
	{ name = "slitF", parent = "base", shape = "box", size = { 2.6, 0.5, 0.1 }, at = { 0, RING - 3, -4.52 }, color = "glass" },
}
for i = 0, 7 do -- reactive blocks round the pad
	local a = i * 45 + 22.5
	local r = math.rad(a)
	table.insert(parts, { name = `era{i}`, parent = "base", shape = "box", size = { 3.6, 1.8, 0.8 }, at = { math.sin(r) * 10, 2.3, math.cos(r) * 10 }, rot = { 0, a, 0 }, color = "metal" })
end
for i = 0, 3 do -- raking struts from the lower rim up the mid drum
	local a = i * 90 + 45
	local r = math.rad(a)
	table.insert(parts, { name = `strut{i}`, parent = "base", shape = "box", size = { 1.2, 9.6, 1.2 }, at = { math.sin(r) * 5.9, 10.8, math.cos(r) * 5.9 }, rot = { -12, a, 0 }, color = "metal" })
end
for i = 0, 5 do -- spikes out of the lower rim
	local a = i * 60
	local r = math.rad(a)
	table.insert(parts, { name = `spike{i}`, parent = "base", shape = "wedge", size = { 0.6, 2.6, 1.2 }, at = { math.sin(r) * 7.9, 7.3, math.cos(r) * 7.9 }, rot = { 25, a + 180, 0 }, color = "metal" })
end
for _, p in {
	{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 9, 4, 9 }, at = { 0, GY, 0.4 }, pivot = { 0, RING, 0 }, color = "hull" },
	{ name = "roofTeam", parent = "turret", shape = "box", size = { 5, 0.1, 4 }, at = { 0, GY + 2.05, 1 }, color = "team" },
	{ name = "cheekL", parent = "turret", shape = "box", size = { 0.6, 3, 4 }, at = { -4.5, GY, -1.2 }, rot = { 0, 20, 0 }, color = "metal" },
	{ name = "cheekR", parent = "turret", shape = "box", size = { 0.6, 3, 4 }, at = { 4.5, GY, -1.2 }, rot = { 0, -20, 0 }, color = "metal" },
	{ name = "gun", parent = "turret", shape = "cylinder", axis = "z", size = { 3.2, 3.2, 5 }, at = { 0, GY, -6.4 }, color = "metal" },
	{ name = "mouth", parent = "turret", shape = "cylinder", axis = "z", size = { 4.2, 4.2, 1.2 }, at = { 0, GY, -9.3 }, color = "dark" },
	{ name = "glow", parent = "turret", shape = "cylinder", axis = "z", size = { 2.2, 2.2, 0.1 }, at = { 0, GY, -9.95 }, color = "glass" },
	{ name = "ammoDrum", parent = "turret", shape = "cylinder", axis = "x", size = { 2, 3.2, 3.2 }, at = { 5.4, GY + 0.2, 1.2 }, color = "metal" },
	{ name = "ammoFeed", parent = "turret", shape = "box", size = { 1, 0.8, 2.4 }, at = { 4.4, GY + 1.2, -1 }, color = "dark" },
	{ name = "lampMast", parent = "turret", shape = "box", size = { 0.3, 2.6, 0.3 }, at = { -2.6, GY + 3.3, 3 }, color = "dark" },
	{ name = "lamp", parent = "turret", shape = "box", size = { 0.8, 0.6, 0.8 }, at = { -2.6, GY + 4.7, 3 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_maw",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "turret", at = { 0, GY, -10.2 } },
	},
}
