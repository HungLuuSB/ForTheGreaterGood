--!strict
-- Supply Vault (Order hardened supply storage, T2, footprint 3; S-209,
-- BAR's armuwadvms): one huge armored storage drum lying across the pad,
-- team bands round it, four heavy armor ribs clamped over it with tie rods
-- along the crown, a loading bay between team-plated feet at the front.
-- Little glow: a sealed vault. Model space, forward = -Z.

local parts: { any } = {
	{ name = "base", shape = "box", size = { 23.6, 0.7, 23.6 }, at = { 0, 0.35, 0 }, color = "dark" },
	{ name = "drum", parent = "base", shape = "cylinder", axis = "x", size = { 18.6, 7.8, 7.8 }, at = { 0, 4.5, 0 }, color = "hull" },
	{ name = "band", parent = "base", shape = "cylinder", axis = "x", size = { 2.2, 7.9, 7.9 }, at = { 0, 4.5, 0 }, color = "team" },
	{ name = "bay", parent = "base", shape = "box", size = { 3.6, 3.4, 1.4 }, at = { 0, 2.4, -6.6 }, color = "hull" },
	{ name = "door", parent = "base", shape = "box", size = { 2.4, 2.4, 0.1 }, at = { 0, 2.2, -7.32 }, color = "dark" },
	{ name = "rodL", parent = "base", shape = "cylinder", axis = "x", size = { 16.6, 0.56, 0.56 }, at = { 0, 9, -1 }, color = "metal" },
	{ name = "rodR", parent = "base", shape = "cylinder", axis = "x", size = { 16.6, 0.56, 0.56 }, at = { 0, 9, 1 }, color = "metal" },
}
for i, x in { -7.4, -2.6, 2.6, 7.4 } do
	table.insert(parts, { name = `rib{i}`, parent = "base", shape = "box", size = { 1.6, 7.9, 12.4 }, at = { x, 4.65, 0 }, color = "dark" })
end
for _, sx in { -1, 1 } do
	for _, sz in { -1, 1 } do
		local tag = `{if sx < 0 then "L" else "R"}{if sz < 0 then "F" else "B"}`
		table.insert(parts, { name = `foot{tag}`, parent = "base", shape = "box", size = { 3, 2.6, 3.6 }, at = { sx * 5, 2, sz * 8.2 }, color = "hull" })
		if sz < 0 then
			table.insert(parts, { name = `footTeam{tag}`, parent = "base", shape = "box", size = { 2.6, 2, 0.1 }, at = { sx * 5, 2.2, -10.05 }, color = "team" })
		end
	end
end

return { id = "ord_advdepot", parts = parts }
