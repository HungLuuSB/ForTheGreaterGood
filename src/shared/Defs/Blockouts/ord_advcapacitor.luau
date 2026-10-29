--!strict
-- Grid Reservoir (Order hardened power storage, T2, footprint 3; S-209,
-- BAR's armuwadves): twin tall armored cell towers wrapped in ribs with
-- team stripes over stacks of glowing charge cells (`cells`, pulse), glowing
-- tops, a waist block joining them, flared side fins with team panels.
-- Power storage reads as glowing cells. Model space, forward = -Z.

local parts: { any } = {
	{ name = "base", shape = "box", size = { 23.6, 0.7, 23.6 }, at = { 0, 0.35, 0 }, color = "dark" },
	{ name = "waist", parent = "base", shape = "box", size = { 7.4, 7.7, 6.8 }, at = { 0, 4.55, 0 }, color = "hull" },
	{ name = "cells", parent = "base", shape = "cylinder", axis = "y", size = { 7.6, 6.6, 7.6 }, at = { -3.7, 5.1, 0 }, color = "glass", anim = { motion = "pulse", axis = { 0, 1, 0 } } },
	{ name = "cellsR", parent = "cells", shape = "cylinder", axis = "y", size = { 7.6, 6.6, 7.6 }, at = { 3.7, 5.1, 0 }, color = "glass" },
}
for _, sx in { -1, 1 } do
	local s = if sx < 0 then "L" else "R"
	table.insert(parts, { name = `foot{s}`, parent = "base", shape = "cylinder", axis = "y", size = { 8.2, 2, 8.2 }, at = { sx * 3.7, 1.7, 0 }, color = "hull" })
	table.insert(parts, { name = `collar{s}`, parent = "base", shape = "cylinder", axis = "y", size = { 8.4, 1.6, 8.4 }, at = { sx * 3.7, 9.6, 0 }, color = "hull" })
	table.insert(parts, { name = `top{s}`, parent = "base", shape = "cylinder", axis = "y", size = { 3.6, 0.1, 3.6 }, at = { sx * 3.7, 10.45, 0 }, color = "glass" })
	table.insert(parts, { name = `stripe{s}`, parent = "base", shape = "box", size = { 0.1, 6, 0.6 }, at = { sx * 7.85, 5.2, 0 }, color = "team" })
	for _, sz in { -1, 1 } do
		local tag = `{s}{if sz < 0 then "F" else "B"}`
		table.insert(parts, { name = `fin{tag}`, parent = "base", shape = "box", size = { 3.2, 3.4, 2 }, at = { sx * 9, 2.4, sz * 3 }, color = "dark" })
		table.insert(parts, { name = `finTeam{tag}`, parent = "base", shape = "box", size = { 0.1, 2.4, 1.6 }, at = { sx * 10.65, 2.2, sz * 3 }, color = "team" })
	end
end

return { id = "ord_advcapacitor", parts = parts }
