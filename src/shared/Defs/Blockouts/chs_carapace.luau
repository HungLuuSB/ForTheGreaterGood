--!strict
-- Carapace (Chaos shield generator, T2 structure, footprint 2; def S-79, dome
-- radius 80): a low skid platform with fuel tanks and exposed pipework; a
-- braced tripod frame over a ring of coils holds the glowing `core` (the
-- def's piece): a bare orange-lit sphere in a cage. The `beam` attachment on
-- top of the core is where the shield's light beam starts
-- (docs/contracts/fx.md). Team plates on the skid. Chaos reads light (M-14).
-- Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 13, 0.8, 13 }, at = { 0, 0.4, 0 }, color = "dark" },
	{ name = "pad", parent = "base", shape = "cylinder", axis = "y", size = { 8, 0.6, 8 }, at = { 0, 1.1, 0 }, color = "hull" },
	{ name = "coilRing", parent = "base", shape = "cylinder", axis = "y", size = { 5.6, 0.8, 5.6 }, at = { 0, 1.8, 0 }, color = "metal" },
	{ name = "coilGlow", parent = "base", shape = "cylinder", axis = "y", size = { 5.8, 0.2, 5.8 }, at = { 0, 2.0, 0 }, color = "glass" },
	{ name = "teamA", parent = "base", shape = "box", size = { 3.2, 0.08, 1.6 }, at = { -4.2, 0.84, 5.2 }, color = "team" },
	{ name = "teamB", parent = "base", shape = "box", size = { 3.2, 0.08, 1.6 }, at = { 4.2, 0.84, -5.2 }, color = "team" },
	{ name = "tankA", parent = "base", shape = "cylinder", axis = "y", size = { 2.0, 2.6, 2.0 }, at = { 5.0, 2.1, 4.6 }, color = "metal" },
	{ name = "tankB", parent = "base", shape = "cylinder", axis = "y", size = { 2.0, 2.6, 2.0 }, at = { -5.0, 2.1, -4.6 }, color = "metal" },
	{ name = "pipeA", parent = "base", shape = "box", size = { 0.35, 0.35, 4.2 }, at = { 3.6, 1.0, 2.6 }, rot = { 0, 40, 0 }, color = "dark" },
	{ name = "pipeB", parent = "base", shape = "box", size = { 0.35, 0.35, 4.2 }, at = { -3.6, 1.0, -2.6 }, rot = { 0, 40, 0 }, color = "dark" },

	-- the core: a bare glowing sphere, the def's piece
	{ name = "core", parent = "base", shape = "ball", size = { 2.2, 2.2, 2.2 }, at = { 0, 6.4, 0 }, color = "glass" },
	{ name = "cageTop", parent = "base", shape = "cylinder", axis = "y", size = { 3.0, 0.2, 3.0 }, at = { 0, 7.9, 0 }, color = "dark" },
	{ name = "cageLow", parent = "base", shape = "cylinder", axis = "y", size = { 3.0, 0.2, 3.0 }, at = { 0, 4.9, 0 }, color = "dark" },
}
-- tripod legs from the pad's rim to the cage
for i = 1, 3 do
	local a = math.pi / 2 + (i - 1) * 2 * math.pi / 3
	local ox, oz = math.cos(a), math.sin(a)
	table.insert(parts, { name = `leg{i}`, parent = "base", shape = "box", size = { 0.3, 7.0, 0.3 }, at = { ox * 2.6, 4.6, oz * 2.6 }, rot = { -16, 90 - math.deg(a), 0 }, color = "dark" })
	table.insert(parts, { name = `cageBar{i}`, parent = "base", shape = "box", size = { 0.15, 3.0, 0.15 }, at = { ox * 1.45, 6.4, oz * 1.45 }, color = "dark" })
end

return {
	id = "chs_carapace",
	parts = parts,
	attachments = {
		{ name = "beam", parent = "core", at = { 0, 7.6, 0 } },
	},
}
