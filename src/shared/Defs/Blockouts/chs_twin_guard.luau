--!strict
-- Twin Guard (Chaos twin laser tower, T1, footprint 2; S-157; F18 2026-10-26:
-- "turret should stand high, proud, tower above others", so taller and
-- heavier, top ~18 studs): the Guard's tall tower (heavy angled skirt, stout
-- round column) with a wider rounded `turret` carrying two Guard laser tubes
-- in ribbed shrouds either side, firing in turn. Each tube is a client piece
-- (`barrel1` left, `barrel2` right) for its own recoil; `muzzle1` /
-- `muzzle2` at their lenses. Both hang from `mount`, which the def pitches
-- -60..+60 degrees. Model space, forward = -Z.

local RING = 14.4 -- top of the column, where the head turns
local BY = RING + 1.6 -- tube height
local BX = 2.1 -- tube offset either side

local parts = {
	{ name = "base", shape = "cylinder", axis = "y", size = { 9.8, 1.2, 9.8 }, at = { 0, 0.6, 0 }, color = "dark" },
	{ name = "footing", parent = "base", shape = "cylinder", axis = "y", size = { 6.2, 3.0, 6.2 }, at = { 0, 2.7, 0 }, color = "dark" },
	{ name = "column", parent = "base", shape = "cylinder", axis = "y", size = { 4.0, RING - 4.2, 4.0 }, at = { 0, 4.2 + (RING - 4.2) / 2, 0 }, color = "hull" },
	{ name = "vent", parent = "base", shape = "box", size = { 1.4, 2.0, 0.2 }, at = { 0, 10.0, -2.0 }, color = "glass" },
	{ name = "band1", parent = "base", shape = "cylinder", axis = "y", size = { 4.3, 0.5, 4.3 }, at = { 0, 5.6, 0 }, color = "metal" },
	{ name = "band2", parent = "base", shape = "cylinder", axis = "y", size = { 4.3, 0.5, 4.3 }, at = { 0, RING - 1.6, 0 }, color = "metal" },
}
for k = 0, 5 do
	local a = math.rad(k * 60 + 30)
	table.insert(parts, { name = `plate{k}`, parent = "base", shape = "box", size = { 4.2, 3.0, 1.0 }, at = { math.sin(a) * 5.1, 2.2, math.cos(a) * 5.1 }, rot = { -24, math.deg(a), 0 }, color = if k % 2 == 0 then "team" else "metal" })
end
for _, p in {
	{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 5.8, 3.0, 5.8 }, at = { 0, RING + 1.5, 0.2 }, pivot = { 0, RING, 0 }, color = "hull" },
	{ name = "roofTeam", parent = "turret", shape = "box", size = { 3.2, 0.08, 2.6 }, at = { 0, RING + 3.04, 0.4 }, color = "team" },
	{ name = "sensor", parent = "turret", shape = "box", size = { 0.8, 0.5, 0.3 }, at = { 0, RING + 2.5, -2.85 }, color = "glass" },

	{ name = "mount", parent = "turret", shape = "box", size = { 5.8, 1.2, 1.2 }, at = { 0, BY, -1.3 }, pivot = { 0, BY, -0.8 }, color = "dark" },
	{ name = "barrel1", parent = "mount", shape = "box", size = { 1.7, 1.7, 3.0 }, at = { -BX, BY, -2.6 }, pivot = { -BX, BY, -1.3 }, color = "hull" },
	{ name = "tube1", parent = "barrel1", shape = "cylinder", axis = "z", size = { 0.95, 0.95, 2.6 }, at = { -BX, BY, -5.4 }, color = "metal" },
	{ name = "lens1", parent = "barrel1", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 0.25 }, at = { -BX, BY, -6.8 }, color = "glass" },
	{ name = "barrel2", parent = "mount", shape = "box", size = { 1.7, 1.7, 3.0 }, at = { BX, BY, -2.6 }, pivot = { BX, BY, -1.3 }, color = "hull" },
	{ name = "tube2", parent = "barrel2", shape = "cylinder", axis = "z", size = { 0.95, 0.95, 2.6 }, at = { BX, BY, -5.4 }, color = "metal" },
	{ name = "lens2", parent = "barrel2", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 0.25 }, at = { BX, BY, -6.8 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_twin_guard",
	visualPieces = { "barrel1", "barrel2" },
	parts = parts,
	attachments = {
		{ name = "muzzle1", parent = "barrel1", at = { -BX, BY, -7.0 } },
		{ name = "muzzle2", parent = "barrel2", at = { BX, BY, -7.0 } },
	},
}
