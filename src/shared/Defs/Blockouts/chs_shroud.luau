--!strict
-- Shroud (Chaos mobile jammer, T2, footprint 1): a light 6 × 6 truck with a
-- tall telescoping lattice mast (wide radius): the `array`, two rings of
-- glowing emitter rods near the top and a beacon; guy-braced. Team plate on
-- the cab roof. Chaos reads light (M-14). Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 4.2, 0.9, 7.2 }, at = { 0, 1.75, 0.1 }, color = "hull" },
	{ name = "cab", parent = "base", shape = "box", size = { 3.8, 1.1, 1.6 }, at = { 0, 2.75, -2.7 }, color = "hull" },
	{ name = "cabSlit", parent = "base", shape = "box", size = { 3.0, 0.2, 0.08 }, at = { 0, 2.95, -3.54 }, color = "glass" },
	{ name = "cabTeam", parent = "base", shape = "box", size = { 2.8, 0.08, 1.0 }, at = { 0, 3.34, -2.7 }, color = "team" },
	{ name = "generator", parent = "base", shape = "box", size = { 3.0, 0.9, 1.4 }, at = { 0, 2.65, -0.6 }, color = "metal" },
	{ name = "mastFoot", parent = "base", shape = "box", size = { 1.4, 0.5, 1.4 }, at = { 0, 2.45, 2.2 }, color = "dark" },

	{ name = "array", parent = "base", shape = "cylinder", axis = "y", size = { 0.6, 6.4, 0.6 }, at = { 0, 5.9, 2.2 }, color = "hull", anim = { motion = "turn", axis = { 0, 1, 0 } } },
	{ name = "arrayUpper", parent = "array", shape = "cylinder", axis = "y", size = { 0.4, 2.4, 0.4 }, at = { 0, 10.3, 2.2 }, color = "hull" },
	{ name = "beacon", parent = "array", shape = "ball", size = { 0.5, 0.5, 0.5 }, at = { 0, 11.7, 2.2 }, color = "glass" },
	{ name = "guyL", parent = "base", shape = "box", size = { 0.08, 6.2, 0.08 }, at = { -1.3, 5.1, 2.2 }, rot = { 0, 0, -12 }, color = "dark" },
	{ name = "guyR", parent = "base", shape = "box", size = { 0.08, 6.2, 0.08 }, at = { 1.3, 5.1, 2.2 }, rot = { 0, 0, 12 }, color = "dark" },
}
for r, y in { 8.4, 9.9 } do
	for k = 0, 3 do
		local a = k * 90 + r * 45
		local rad = math.rad(a)
		table.insert(parts, { name = `rod{r}{k}`, parent = "array", shape = "box", size = { 0.15, 0.15, 1.4 }, at = { math.sin(rad) * 0.8, y, 2.2 + math.cos(rad) * 0.8 }, rot = { 0, a, 0 }, color = "glass" })
	end
end
for i, z in { -2.5, 0.6, 2.5 } do
	table.insert(parts, { name = `wheelL{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.6, 1.6, 1.6 }, at = { -2.1, 0.8, z }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } })
	table.insert(parts, { name = `wheelR{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.6, 1.6, 1.6 }, at = { 2.1, 0.8, z }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } })
end

return { id = "chs_shroud", parts = parts }
