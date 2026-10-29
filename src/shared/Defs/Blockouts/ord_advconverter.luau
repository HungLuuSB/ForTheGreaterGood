--!strict
-- Advanced Supply Converter (Order T2 converter, footprint 3; S-209, BAR's
-- armmmkr): the T1 converter's coil column laid down as a coil tunnel. A
-- long arched hull across the pad ribbed by armored arches, glowing coil
-- bands between them (`coil`, pulse), armored end blocks with team panels,
-- splayed feet. Model space, forward = -Z.

local parts: { any } = {
	{ name = "base", shape = "box", size = { 23.6, 0.7, 23.6 }, at = { 0, 0.35, 0 }, color = "dark" },
	{ name = "hull", parent = "base", shape = "cylinder", axis = "x", size = { 15.2, 10, 10 }, at = { 0, 0.7, 0 }, color = "dark" },
	{ name = "coil", parent = "base", shape = "cylinder", axis = "x", size = { 12.6, 10.8, 10.8 }, at = { 0, 0.7, 0 }, color = "glass", anim = { motion = "pulse", axis = { 0, 1, 0 } } },
	{ name = "spine", parent = "base", shape = "cylinder", axis = "x", size = { 14.6, 0.6, 0.6 }, at = { 0, 8.65, 0 }, color = "metal" },
	{ name = "endL", parent = "base", shape = "box", size = { 3, 4.3, 9.2 }, at = { -9.1, 2.85, 0 }, color = "hull" },
	{ name = "endR", parent = "base", shape = "box", size = { 3, 4.3, 9.2 }, at = { 9.1, 2.85, 0 }, color = "hull" },
	{ name = "teamL", parent = "base", shape = "box", size = { 2.4, 0.1, 5.2 }, at = { -9.1, 5.05, 0 }, color = "team" },
	{ name = "teamR", parent = "base", shape = "box", size = { 2.4, 0.1, 5.2 }, at = { 9.1, 5.05, 0 }, color = "team" },
}
for i, x in { -7, -3.5, 0, 3.5, 7 } do
	table.insert(parts, { name = `rib{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 1, 12, 12 }, at = { x, 0.7, 0 }, color = "hull" })
end
for _, sx in { -1, 1 } do
	for _, sz in { -1, 1 } do
		local tag = `{if sx < 0 then "L" else "R"}{if sz < 0 then "F" else "B"}`
		table.insert(parts, { name = `foot{tag}`, parent = "base", shape = "box", size = { 2.8, 1.6, 3.4 }, at = { sx * 8, 1.5, sz * 6.8 }, color = "hull" })
		table.insert(parts, { name = `footTeam{tag}`, parent = "base", shape = "box", size = { 2.4, 0.1, 1.6 }, at = { sx * 8, 2.35, sz * 6.8 }, color = "team" })
	end
end

return { id = "ord_advconverter", parts = parts }
