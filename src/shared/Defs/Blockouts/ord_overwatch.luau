--!strict
-- Overwatch (Order twin laser tower, T1, footprint 2; S-157; the user's
-- reference 2026-10-24: a flared base, a thin mast, a wide head): a flared
-- footing ringed with lit vents and four corner fins, a thin tall mast, and
-- on top the `turret`, a wide saucer head with a lit dome, a team band and
-- a long green laser barrel on each side, firing in turn. Each barrel is a
-- client piece (`barrel1` left, `barrel2` right) for its own recoil;
-- `muzzle1` / `muzzle2` at their lenses. Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "cylinder", axis = "y", size = { 8.4, 1.0, 8.4 }, at = { 0, 0.5, 0 }, color = "dark" },
	{ name = "flare", parent = "base", shape = "cylinder", axis = "y", size = { 6.4, 3.0, 6.4 }, at = { 0, 2.5, 0 }, color = "hull" },
	{ name = "vents", parent = "base", shape = "cylinder", axis = "y", size = { 6.5, 1.4, 6.5 }, at = { 0, 2.4, 0 }, color = "glass" },
	{ name = "neck", parent = "base", shape = "cylinder", axis = "y", size = { 3.6, 2.4, 3.6 }, at = { 0, 5.2, 0 }, color = "hull" },
	{ name = "mast", parent = "base", shape = "cylinder", axis = "y", size = { 1.2, 5.4, 1.2 }, at = { 0, 9.1, 0 }, color = "dark" },
}
for k = 0, 3 do
	local a = math.rad(k * 90 + 45)
	table.insert(parts, { name = `fin{k}`, parent = "base", shape = "box", size = { 0.5, 2.6, 1.8 }, at = { math.sin(a) * 3.6, 1.8, math.cos(a) * 3.6 }, rot = { 0, math.deg(a), 0 }, color = "hull" })
end
for _, p in {
	{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 5.6, 1.6, 4.6 }, at = { 0, 12.4, 0 }, pivot = { 0, 11.8, 0 }, color = "hull" },
	{ name = "teamBand", parent = "turret", shape = "box", size = { 1.6, 1.7, 4.0 }, at = { 0, 12.5, 0 }, color = "team" },
	{ name = "dome", parent = "turret", shape = "ball", size = { 1.4, 1.4, 1.4 }, at = { 0, 13.5, 0.4 }, color = "glass" },
	{ name = "lightL", parent = "turret", shape = "box", size = { 0.6, 0.2, 0.1 }, at = { -1.6, 12.6, -2.0 }, color = "glass" },
	{ name = "lightR", parent = "turret", shape = "box", size = { 0.6, 0.2, 0.1 }, at = { 1.6, 12.6, -2.0 }, color = "glass" },

	{ name = "barrel1", parent = "turret", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 4.4 }, at = { -2.6, 12.2, -3.4 }, pivot = { -2.6, 12.2, -1.2 }, color = "metal" },
	{ name = "lens1", parent = "barrel1", shape = "cylinder", axis = "z", size = { 0.45, 0.45, 0.2 }, at = { -2.6, 12.2, -5.65 }, color = "glass" },
	{ name = "barrel2", parent = "turret", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 4.4 }, at = { 2.6, 12.2, -3.4 }, pivot = { 2.6, 12.2, -1.2 }, color = "metal" },
	{ name = "lens2", parent = "barrel2", shape = "cylinder", axis = "z", size = { 0.45, 0.45, 0.2 }, at = { 2.6, 12.2, -5.65 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_overwatch",
	visualPieces = { "barrel1", "barrel2" },
	parts = parts,
	attachments = {
		{ name = "muzzle1", parent = "barrel1", at = { -2.6, 12.2, -5.8 } },
		{ name = "muzzle2", parent = "barrel2", at = { 2.6, 12.2, -5.8 } },
	},
}
