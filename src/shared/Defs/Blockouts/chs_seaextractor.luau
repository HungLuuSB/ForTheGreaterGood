--!strict
-- Sunken Excavator (Chaos submerged extractor, T1, footprint 2; S-209, BAR
-- cormex): on the seabed, a heavy dark platform ringed by a pipe loop, a
-- hexagonal pump house with bulky armor blocks round it, and on top a
-- turning three-armed cutter (`drill`, turn Y) with heavy perforated heads.
-- Chaos reads rugged (M-14). Model space, forward = -Z.

local TOP = 4.4

local parts: { any } = {
	{ name = "base", shape = "box", size = { 15.2, 1.0, 15.2 }, at = { 0, 0.5, 0 }, color = "dark" },
	{ name = "house", parent = "base", shape = "cylinder", axis = "y", size = { 5.2, TOP - 1.0, 5.2 }, at = { 0, 1.0 + (TOP - 1.0) / 2, 0 }, color = "metal" },
	{ name = "window", parent = "base", shape = "box", size = { 1.8, 0.5, 0.1 }, at = { 0, 3.0, -2.6 }, color = "glass" },
	{ name = "drill", parent = "base", shape = "cylinder", axis = "y", size = { 3.0, 0.8, 3.0 }, at = { 0, TOP + 0.4, 0 }, color = "metal", anim = { motion = "turn", axis = { 0, 1, 0 } } },
}
for k = 0, 5 do
	local a = math.rad(60 * k)
	table.insert(parts, { name = `block{k}`, parent = "base", shape = "box", size = { 2.6, 1.8, 2.0 }, at = { math.sin(a) * 4.0, 2.1, -math.cos(a) * 4.0 }, rot = { 0, -math.deg(a), 0 }, color = if k % 2 == 0 then "team" else "hull" })
end
for k = 0, 2 do
	local a = math.rad(90 + 120 * k)
	table.insert(parts, { name = `arm{k}`, parent = "drill", shape = "box", size = { 6.6, 0.8, 0.9 }, at = { math.cos(a) * 3.1, TOP + 0.75, math.sin(a) * 3.1 }, rot = { 0, -math.deg(a), 0 }, color = "hull" })
	table.insert(parts, { name = `cutter{k}`, parent = "drill", shape = "box", size = { 1.8, 1.9, 1.3 }, at = { math.cos(a) * 4.4, TOP + 0.85, math.sin(a) * 4.4 }, rot = { 0, -math.deg(a), 0 }, color = "dark" })
end

return { id = "chs_seaextractor", parts = parts }
