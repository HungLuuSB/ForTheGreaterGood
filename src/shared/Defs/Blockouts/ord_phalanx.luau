--!strict
-- Phalanx (Order shield generator, T2 structure, footprint 2; def S-79, dome
-- radius 120): a stepped armored block with four capacitor posts at its
-- corners and a raised deck carrying the shield emitter: a hex plinth, three
-- prongs leaning in round the glowing `core` (the def's piece). The `beam`
-- attachment on top of the core is where the shield's light beam starts
-- (docs/contracts/fx.md). Team plates on the lower ring. Order reads heavy
-- and fortress-like (M-14). Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 14, 1.2, 14 }, at = { 0, 0.6, 0 }, color = "hull" },
	{ name = "wallF", parent = "base", shape = "wedge", size = { 14, 1.2, 1.0 }, at = { 0, 0.6, -7.5 }, color = "hull" },
	{ name = "wallB", parent = "base", shape = "wedge", size = { 14, 1.2, 1.0 }, at = { 0, 0.6, 7.5 }, rot = { 0, 180, 0 }, color = "hull" },
	{ name = "wallL", parent = "base", shape = "wedge", size = { 14, 1.2, 1.0 }, at = { -7.5, 0.6, 0 }, rot = { 0, 90, 0 }, color = "hull" },
	{ name = "wallR", parent = "base", shape = "wedge", size = { 14, 1.2, 1.0 }, at = { 7.5, 0.6, 0 }, rot = { 0, -90, 0 }, color = "hull" },
	{ name = "block", parent = "base", shape = "box", size = { 9, 1.8, 9 }, at = { 0, 2.1, 0 }, color = "hull" },
	{ name = "deck", parent = "base", shape = "cylinder", axis = "y", size = { 6.4, 1.0, 6.4 }, at = { 0, 3.5, 0 }, color = "dark" },
	{ name = "teamF", parent = "base", shape = "box", size = { 4, 0.1, 1.2 }, at = { 0, 1.25, -5.6 }, color = "team" },
	{ name = "teamB", parent = "base", shape = "box", size = { 4, 0.1, 1.2 }, at = { 0, 1.25, 5.6 }, color = "team" },
	{ name = "teamL", parent = "base", shape = "box", size = { 1.2, 0.1, 4 }, at = { -5.6, 1.25, 0 }, color = "team" },
	{ name = "teamR", parent = "base", shape = "box", size = { 1.2, 0.1, 4 }, at = { 5.6, 1.25, 0 }, color = "team" },
	{ name = "plinth", parent = "base", shape = "cylinder", axis = "y", size = { 4.4, 0.9, 4.4 }, at = { 0, 4.45, 0 }, color = "hull" },
	{ name = "collar", parent = "base", shape = "cylinder", axis = "y", size = { 3.0, 0.8, 3.0 }, at = { 0, 5.3, 0 }, color = "dark" },

	-- the core: a glowing column, the def's piece
	{ name = "core", parent = "base", shape = "cylinder", axis = "y", size = { 1.2, 2.6, 1.2 }, at = { 0, 7.0, 0 }, color = "glass" },
}
for i, c in { { -5.4, -5.4 }, { 5.4, -5.4 }, { -5.4, 5.4 }, { 5.4, 5.4 } } do
	table.insert(parts, { name = `post{i}`, parent = "base", shape = "cylinder", axis = "y", size = { 1.2, 3.2, 1.2 }, at = { c[1], 2.8, c[2] }, color = "metal" })
	table.insert(parts, { name = `postBand{i}`, parent = "base", shape = "cylinder", axis = "y", size = { 1.35, 0.25, 1.35 }, at = { c[1], 3.6, c[2] }, color = "glass" })
	table.insert(parts, { name = `postCap{i}`, parent = "base", shape = "box", size = { 1.5, 0.3, 1.5 }, at = { c[1], 4.55, c[2] }, color = "dark" })
end
for i = 1, 3 do
	local a = math.pi / 2 + (i - 1) * 2 * math.pi / 3
	local ox, oz = math.cos(a), math.sin(a)
	-- prongs from the plinth's rim up to beside the core's top, leaning in 16°
	table.insert(parts, { name = `prong{i}`, parent = "base", shape = "box", size = { 1.1, 4.4, 0.75 }, at = { ox * 1.95, 7.0, oz * 1.95 }, rot = { -16, 90 - math.deg(a), 0 }, color = "hull" })
	table.insert(parts, { name = `prongTip{i}`, parent = "base", shape = "box", size = { 0.75, 0.45, 0.9 }, at = { ox * 1.45, 9.35, oz * 1.45 }, color = "dark" })
end

return {
	id = "ord_phalanx",
	parts = parts,
	attachments = {
		{ name = "beam", parent = "core", at = { 0, 8.3, 0 } },
	},
}
