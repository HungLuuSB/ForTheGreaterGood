--!strict
-- Advanced Extractor (Order, T2, footprint 2; the user 2026-10-26: "T2 of
-- the T1 extractor must be the same size, they should look like an upgrade
-- version"): the T1 Extractor upgraded in place on its 2 x 2 deposit patch
-- (S-108). The same chamfered slab and octagonal armored housing with its
-- team deck, then a second armored tier with a lit band and radiator fins,
-- and a taller drill tower (`drill`, client-turned) with two glowing power
-- bands and a four-armed crown; twin pumps in front, ore hoppers behind,
-- corner anchor lights. About 11 studs tall to the T1's 6. Order reads
-- clean and heavy (M-14). Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 15.6, 0.8, 15.6 }, at = { 0, 0.4, 0 }, color = "dark" },
	-- the T1's octagonal housing and team deck
	{ name = "housing", parent = "base", shape = "box", size = { 10, 3, 10 }, at = { 0, 2.3, 0 }, color = "hull" },
	{ name = "housing45", parent = "base", shape = "box", size = { 8.6, 3, 8.6 }, at = { 0, 2.3, 0 }, rot = { 0, 45, 0 }, color = "hull" },
	{ name = "deck", parent = "base", shape = "box", size = { 9, 0.12, 9 }, at = { 0, 3.86, 0 }, color = "team" },
	{ name = "door", parent = "base", shape = "box", size = { 2.2, 2, 0.1 }, at = { 0, 1.8, -5.05 }, color = "dark" },
	{ name = "doorLight", parent = "base", shape = "box", size = { 3.4, 0.2, 0.1 }, at = { 0, 3.1, -5.06 }, color = "glass" },
	-- the upgrade: a second armored tier
	{ name = "tier", parent = "base", shape = "box", size = { 6.6, 2.6, 6.6 }, at = { 0, 5.1, 0 }, color = "hull" },
	{ name = "tier45", parent = "base", shape = "box", size = { 5.8, 2.6, 5.8 }, at = { 0, 5.1, 0 }, rot = { 0, 45, 0 }, color = "hull" },
	{ name = "tierBand", parent = "base", shape = "box", size = { 6.7, 0.3, 6.7 }, at = { 0, 4.6, 0 }, color = "glass" },
	{ name = "tierCap", parent = "base", shape = "cylinder", axis = "y", size = { 5.4, 0.5, 5.4 }, at = { 0, 6.65, 0 }, color = "dark" },
	-- twin pumps in front, hoppers behind, anchors at the corners
	{ name = "hazardF", parent = "base", shape = "box", size = { 6, 0.06, 0.7 }, at = { 0, 0.83, -6.9 }, color = "hazard" },
}
for _, sx in { -1, 1 } do
	local tag = if sx < 0 then "L" else "R"
	table.insert(parts, { name = `fin{tag}1`, parent = "base", shape = "box", size = { 0.2, 1.8, 4.4 }, at = { sx * 3.45, 5.2, -0.8 }, color = "metal" })
	table.insert(parts, { name = `fin{tag}2`, parent = "base", shape = "box", size = { 0.2, 1.8, 4.4 }, at = { sx * 3.8, 5.2, -0.8 }, color = "metal" })
	table.insert(parts, { name = `pump{tag}`, parent = "base", shape = "cylinder", axis = "x", size = { 2.6, 2.2, 2.2 }, at = { sx * 6.2, 2.0, -3.6 }, color = "metal" })
	table.insert(parts, { name = `pumpBase{tag}`, parent = "base", shape = "box", size = { 2.8, 0.8, 2.8 }, at = { sx * 6.2, 1.2, -3.6 }, color = "dark" })
	table.insert(parts, { name = `pumpValve{tag}`, parent = "base", shape = "cylinder", axis = "y", size = { 0.5, 1.6, 0.5 }, at = { sx * 6.2, 3.6, -3.6 }, color = "dark" })
	table.insert(parts, { name = `hopper{tag}`, parent = "base", shape = "wedge", size = { 3.2, 3, 3 }, at = { sx * 5.4, 2.3, 5.6 }, rot = { 0, 180, 0 }, color = "hull" })
	table.insert(parts, { name = `conveyor{tag}`, parent = "base", shape = "box", size = { 0.8, 0.3, 4.4 }, at = { sx * 3.2, 3.6, 4.4 }, rot = { -20, 0, 0 }, color = "dark" })
	for _, sz in { -1, 1 } do
		table.insert(parts, { name = `anchor{tag}{sz}`, parent = "base", shape = "box", size = { 1.6, 1.2, 1.6 }, at = { sx * 6.9, 1.4, sz * 6.9 }, color = "hull" })
		table.insert(parts, { name = `anchorLight{tag}{sz}`, parent = "base", shape = "box", size = { 0.7, 0.2, 0.7 }, at = { sx * 6.9, 2.1, sz * 6.9 }, color = "glass" })
	end
end
-- the drill tower: client-turned, with its glowing bands and crown
table.insert(parts, { name = "drill", parent = "base", shape = "cylinder", axis = "y", size = { 3, 4.4, 3 }, at = { 0, 9.1, 0 }, color = "metal", anim = { motion = "turn", axis = { 0, 1, 0 } } })
for _, p in {
	{ name = "band1", parent = "drill", shape = "cylinder", axis = "y", size = { 3.3, 0.35, 3.3 }, at = { 0, 7.9, 0 }, color = "glass" },
	{ name = "band2", parent = "drill", shape = "cylinder", axis = "y", size = { 3.3, 0.35, 3.3 }, at = { 0, 9.7, 0 }, color = "glass" },
	{ name = "crown", parent = "drill", shape = "cylinder", axis = "y", size = { 2.2, 0.8, 2.2 }, at = { 0, 11.7, 0 }, color = "dark" },
	{ name = "crownTip", parent = "drill", shape = "cylinder", axis = "y", size = { 1.2, 0.5, 1.2 }, at = { 0, 12.35, 0 }, color = "glass" },
	{ name = "armX", parent = "drill", shape = "box", size = { 5.4, 0.5, 0.7 }, at = { 0, 11.0, 0 }, color = "metal" },
	{ name = "armZ", parent = "drill", shape = "box", size = { 0.7, 0.5, 5.4 }, at = { 0, 11.0, 0 }, color = "metal" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_advextractor",
	parts = parts,
}
