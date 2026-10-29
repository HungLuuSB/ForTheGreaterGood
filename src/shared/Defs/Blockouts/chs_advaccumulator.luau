--!strict
-- Great Accumulator (Chaos hardened power storage, T2, footprint 3; S-209,
-- BAR's coruwadves): an octagonal bunker of armor blocks, each with a
-- glowing charge cell (`cells`, pulse), a sloped shoulder, four team
-- buttresses on the diagonals climbing to an armored dome with a glowing
-- cross on top. Power storage reads as glowing cells. Model space,
-- forward = -Z.

local parts: { any } = {
	{ name = "base", shape = "box", size = { 23.4, 0.6, 23.4 }, at = { 0, 0.3, 0 }, color = "dark" },
	{ name = "bunker", parent = "base", shape = "cylinder", axis = "y", size = { 17.4, 3.8, 17.4 }, at = { 0, 2.5, 0 }, color = "hull" },
	{ name = "cells", parent = "base", shape = "cylinder", axis = "y", size = { 17.8, 2.2, 17.8 }, at = { 0, 2.7, 0 }, color = "glass", anim = { motion = "pulse", axis = { 0, 1, 0 } } },
	{ name = "shoulder", parent = "base", shape = "cylinder", axis = "y", size = { 17.6, 1.2, 17.6 }, at = { 0, 5, 0 }, color = "dark" },
	{ name = "dome", parent = "base", shape = "cylinder", axis = "y", size = { 12.2, 2.6, 12.2 }, at = { 0, 6.9, 0 }, color = "hull" },
	{ name = "crossA", parent = "base", shape = "box", size = { 6, 0.1, 0.9 }, at = { 0, 8.25, 0 }, color = "glass" },
	{ name = "crossB", parent = "base", shape = "box", size = { 0.9, 0.1, 6 }, at = { 0, 8.25, 0 }, color = "glass" },
}
for _, sx in { -1, 1 } do
	for _, sz in { -1, 1 } do
		local tag = `{if sx < 0 then "L" else "R"}{if sz < 0 then "F" else "B"}`
		table.insert(parts, { name = `buttress{tag}`, parent = "base", shape = "box", size = { 2.4, 5.6, 6 }, at = { sx * 7.4, 3.4, sz * 7.4 }, rot = { 0, sx * sz * 45, 0 }, color = "hull" })
		table.insert(parts, { name = `team{tag}`, parent = "base", shape = "box", size = { 2.5, 3.4, 3.6 }, at = { sx * 7.4, 3.2, sz * 7.4 }, rot = { 0, sx * sz * 45, 0 }, color = "team" })
	end
end

return { id = "chs_advaccumulator", parts = parts }
