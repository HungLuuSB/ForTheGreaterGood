--!strict
-- Overwatch (Order twin laser tower, T1, footprint 2; S-157; the user's
-- reference 2026-10-24: a flared base, a thin mast, a wide head; F18
-- 2026-10-26: "turret should stand high, proud, tower above others", so
-- taller and heavier, top ~19 studs): a flared footing ringed with lit vents
-- and four corner fins, a thin tall mast, and on top the `turret`, a wide
-- saucer head with a lit dome, a team band and a long green laser barrel on
-- each side, firing in turn. Each barrel is a client piece (`barrel1` left,
-- `barrel2` right) for its own recoil; `muzzle1` / `muzzle2` at their
-- lenses. Both hang from `mount`, a trunnion bar the def pitches -60..+60
-- degrees. Model space, forward = -Z.

local RING = 15.8 -- top of the mast, where the head turns
local BY = RING + 0.6 -- barrel height
local BX = 3.4 -- barrel offset either side

local parts = {
	{ name = "base", shape = "cylinder", axis = "y", size = { 11.0, 1.0, 11.0 }, at = { 0, 0.5, 0 }, color = "dark" },
	{ name = "flare", parent = "base", shape = "cylinder", axis = "y", size = { 8.4, 3.6, 8.4 }, at = { 0, 2.8, 0 }, color = "hull" },
	{ name = "vents", parent = "base", shape = "cylinder", axis = "y", size = { 8.5, 1.6, 8.5 }, at = { 0, 2.7, 0 }, color = "glass" },
	{ name = "neck", parent = "base", shape = "cylinder", axis = "y", size = { 4.6, 3.0, 4.6 }, at = { 0, 6.1, 0 }, color = "hull" },
	{ name = "mast", parent = "base", shape = "cylinder", axis = "y", size = { 1.6, RING - 7.6, 1.6 }, at = { 0, 7.6 + (RING - 7.6) / 2, 0 }, color = "dark" },
	{ name = "mastBand", parent = "base", shape = "cylinder", axis = "y", size = { 2.0, 0.4, 2.0 }, at = { 0, RING - 2.6, 0 }, color = "glass" },
}
for k = 0, 3 do
	local a = math.rad(k * 90 + 45)
	table.insert(parts, { name = `fin{k}`, parent = "base", shape = "box", size = { 0.6, 3.4, 2.4 }, at = { math.sin(a) * 4.7, 2.3, math.cos(a) * 4.7 }, rot = { 0, math.deg(a), 0 }, color = "hull" })
end
for _, p in {
	{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 7.4, 2.0, 6.0 }, at = { 0, RING + 0.8, 0 }, pivot = { 0, RING, 0 }, color = "hull" },
	{ name = "teamBand", parent = "turret", shape = "box", size = { 2.0, 2.1, 5.4 }, at = { 0, RING + 0.9, 0 }, color = "team" },
	{ name = "dome", parent = "turret", shape = "ball", size = { 1.8, 1.8, 1.8 }, at = { 0, RING + 2.1, 0.5 }, color = "glass" },
	{ name = "lightL", parent = "turret", shape = "box", size = { 0.8, 0.25, 0.1 }, at = { -2.1, RING + 1.0, -2.6 }, color = "glass" },
	{ name = "lightR", parent = "turret", shape = "box", size = { 0.8, 0.25, 0.1 }, at = { 2.1, RING + 1.0, -2.6 }, color = "glass" },

	{ name = "mount", parent = "turret", shape = "box", size = { 7.6, 1.0, 1.5 }, at = { 0, BY, -1.3 }, pivot = { 0, BY, -0.8 }, color = "dark" },
	{ name = "barrel1", parent = "mount", shape = "cylinder", axis = "z", size = { 0.8, 0.8, 5.8 }, at = { -BX, BY, -4.4 }, pivot = { -BX, BY, -1.5 }, color = "metal" },
	{ name = "coil1", parent = "barrel1", shape = "cylinder", axis = "z", size = { 1.2, 1.2, 0.5 }, at = { -BX, BY, -5.6 }, color = "dark" },
	{ name = "lens1", parent = "barrel1", shape = "cylinder", axis = "z", size = { 0.65, 0.65, 0.25 }, at = { -BX, BY, -7.35 }, color = "glass" },
	{ name = "barrel2", parent = "mount", shape = "cylinder", axis = "z", size = { 0.8, 0.8, 5.8 }, at = { BX, BY, -4.4 }, pivot = { BX, BY, -1.5 }, color = "metal" },
	{ name = "coil2", parent = "barrel2", shape = "cylinder", axis = "z", size = { 1.2, 1.2, 0.5 }, at = { BX, BY, -5.6 }, color = "dark" },
	{ name = "lens2", parent = "barrel2", shape = "cylinder", axis = "z", size = { 0.65, 0.65, 0.25 }, at = { BX, BY, -7.35 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_overwatch",
	visualPieces = { "barrel1", "barrel2" },
	parts = parts,
	attachments = {
		{ name = "muzzle1", parent = "barrel1", at = { -BX, BY, -7.6 } },
		{ name = "muzzle2", parent = "barrel2", at = { BX, BY, -7.6 } },
	},
}
