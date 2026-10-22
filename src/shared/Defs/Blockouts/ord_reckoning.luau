--!strict
-- Reckoning (Order nuclear silo, T3, footprint 3): a stepped square armored
-- bunker with sloped blast walls on every side; its roof is one unmistakable
-- silo top (review 2026-10-22: it must never read as a Citadel from above):
-- two huge split blast doors fill most of the roof, ringed by a yellow and
-- black hazard edge. `hatch` (the def's piece) is the left door, hinged at
-- its outer edge; `hatch2` (client-only) the right one; both swing up and
-- out to launch. Team plates on the lower ring. Order reads heavy and
-- fortress-like (M-14). Model space, forward = -Z (docs/contracts/rig.md).

local parts = {
	{ name = "base", shape = "box", size = { 20, 1.2, 20 }, at = { 0, 0.6, 0 }, color = "hull" },
	{ name = "wallF", parent = "base", shape = "wedge", size = { 20, 1.4, 2 }, at = { 0, 0.7, -11 }, color = "hull" },
	{ name = "wallB", parent = "base", shape = "wedge", size = { 20, 1.4, 2 }, at = { 0, 0.7, 11 }, rot = { 0, 180, 0 }, color = "hull" },
	{ name = "wallL", parent = "base", shape = "wedge", size = { 20, 1.4, 2 }, at = { -11, 0.7, 0 }, rot = { 0, 90, 0 }, color = "hull" },
	{ name = "wallR", parent = "base", shape = "wedge", size = { 20, 1.4, 2 }, at = { 11, 0.7, 0 }, rot = { 0, -90, 0 }, color = "hull" },
	{ name = "block", parent = "base", shape = "box", size = { 15, 1.4, 15 }, at = { 0, 1.9, 0 }, color = "hull" },
	{ name = "pit", parent = "base", shape = "box", size = { 12.4, 0.1, 12.4 }, at = { 0, 2.62, 0 }, color = "dark" },
	{ name = "teamNW", parent = "base", shape = "box", size = { 2.2, 0.1, 2.2 }, at = { -8.6, 1.25, -8.6 }, color = "team" },
	{ name = "teamNE", parent = "base", shape = "box", size = { 2.2, 0.1, 2.2 }, at = { 8.6, 1.25, -8.6 }, color = "team" },
	{ name = "teamSW", parent = "base", shape = "box", size = { 2.2, 0.1, 2.2 }, at = { -8.6, 1.25, 8.6 }, color = "team" },
	{ name = "teamSE", parent = "base", shape = "box", size = { 2.2, 0.1, 2.2 }, at = { 8.6, 1.25, 8.6 }, color = "team" },
	{ name = "lightNW", parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { -9.3, 1.5, -6.6 }, color = "glass" },
	{ name = "lightNE", parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { 9.3, 1.5, -6.6 }, color = "glass" },
	{ name = "lightSW", parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { -9.3, 1.5, 6.6 }, color = "glass" },
	{ name = "lightSE", parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { 9.3, 1.5, 6.6 }, color = "glass" },

	-- the doors: 6 × 12 each with a seam between, ribbed, a team stripe each
	{ name = "hatch", parent = "base", shape = "box", size = { 6.0, 0.5, 12 }, at = { -3.05, 2.85, 0 }, pivot = { -6.05, 3.1, 0 }, color = "metal", anim = { motion = "open", axis = { 0, 0, 1 }, range = 110 } },
	{ name = "ribL1", parent = "hatch", shape = "box", size = { 5.4, 0.2, 0.4 }, at = { -3.05, 3.2, -3.5 }, color = "dark" },
	{ name = "ribL2", parent = "hatch", shape = "box", size = { 5.4, 0.2, 0.4 }, at = { -3.05, 3.2, 3.5 }, color = "dark" },
	{ name = "doorTeamL", parent = "hatch", shape = "box", size = { 1.4, 0.08, 5.6 }, at = { -3.05, 3.14, 0 }, color = "team" },
	{ name = "hatch2", parent = "base", shape = "box", size = { 6.0, 0.5, 12 }, at = { 3.05, 2.85, 0 }, pivot = { 6.05, 3.1, 0 }, color = "metal", anim = { motion = "open", axis = { 0, 0, -1 }, range = 110 } },
	{ name = "ribR1", parent = "hatch2", shape = "box", size = { 5.4, 0.2, 0.4 }, at = { 3.05, 3.2, -3.5 }, color = "dark" },
	{ name = "ribR2", parent = "hatch2", shape = "box", size = { 5.4, 0.2, 0.4 }, at = { 3.05, 3.2, 3.5 }, color = "dark" },
	{ name = "doorTeamR", parent = "hatch2", shape = "box", size = { 1.4, 0.08, 5.6 }, at = { 3.05, 3.14, 0 }, color = "team" },
}

-- hazard edge round the doors: alternating yellow and dark blocks, 8 a side
-- plus yellow corners
local SEG, EDGE, Y = 1.6, 6.8, 2.75
for side = 1, 4 do
	for i = 0, 7 do
		local t = -6.4 + SEG * (i + 0.5)
		local x, z, sx, sz
		if side == 1 then
			x, z, sx, sz = t, -EDGE, SEG, 0.8
		elseif side == 2 then
			x, z, sx, sz = EDGE, t, 0.8, SEG
		elseif side == 3 then
			x, z, sx, sz = -t, EDGE, SEG, 0.8
		else
			x, z, sx, sz = -EDGE, -t, 0.8, SEG
		end
		table.insert(parts, { name = `hazard{side}_{i}`, parent = "base", shape = "box", size = { sx, 0.25, sz }, at = { x, Y, z }, color = if i % 2 == 0 then "dark" else "hazard" })
	end
	local cx, cz = (if side <= 2 then 1 else -1) * EDGE, (if side % 2 == 1 then 1 else -1) * EDGE
	table.insert(parts, { name = `hazardCorner{side}`, parent = "base", shape = "box", size = { 0.8, 0.25, 0.8 }, at = { cx, Y, cz }, color = "hazard" })
end

-- footprint 3 -> 6 (size scale, M-26 / S-104): scaled until the redesign lands
return require("./Scale").scaled({
	id = "ord_reckoning",
	visualPieces = { "hatch2" },
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "base", at = { 0, 2.8, 0 } },
	},
}, 1.94)
