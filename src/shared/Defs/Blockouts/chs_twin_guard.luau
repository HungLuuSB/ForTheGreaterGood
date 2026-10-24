--!strict
-- Twin Guard (Chaos twin laser tower, T1, footprint 2; S-157): the Guard's
-- tall tower (heavy angled skirt, stout octagonal column) with a wider
-- rounded `turret` carrying two Guard laser tubes in ribbed shrouds either
-- side, firing in turn. Each tube is a client piece (`barrel1` left,
-- `barrel2` right) for its own recoil; `muzzle1` / `muzzle2` at their lenses.
-- Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "cylinder", axis = "y", size = { 7.2, 1.2, 7.2 }, at = { 0, 0.6, 0 }, color = "dark" },
	{ name = "footing", parent = "base", shape = "cylinder", axis = "y", size = { 4.8, 2.4, 4.8 }, at = { 0, 2.2, 0 }, color = "dark" },
	{ name = "column", parent = "base", shape = "cylinder", axis = "y", size = { 3.2, 6.6, 3.2 }, at = { 0, 6.7, 0 }, color = "hull" },
	{ name = "vent", parent = "base", shape = "box", size = { 1.2, 1.6, 0.2 }, at = { 0, 7.4, -1.6 }, color = "glass" },
	{ name = "band1", parent = "base", shape = "cylinder", axis = "y", size = { 3.5, 0.4, 3.5 }, at = { 0, 4.4, 0 }, color = "metal" },
	{ name = "band2", parent = "base", shape = "cylinder", axis = "y", size = { 3.5, 0.4, 3.5 }, at = { 0, 9.4, 0 }, color = "metal" },
}
for k = 0, 5 do
	local a = math.rad(k * 60 + 30)
	table.insert(parts, { name = `plate{k}`, parent = "base", shape = "box", size = { 3.4, 2.4, 0.8 }, at = { math.sin(a) * 3.9, 1.8, math.cos(a) * 3.9 }, rot = { -24, math.deg(a), 0 }, color = if k % 2 == 0 then "team" else "metal" })
end
for _, p in {
	{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 4.4, 2.4, 4.4 }, at = { 0, 11.2, 0.2 }, pivot = { 0, 10.0, 0 }, color = "hull" },
	{ name = "roofTeam", parent = "turret", shape = "box", size = { 2.4, 0.08, 2.0 }, at = { 0, 12.44, 0.4 }, color = "team" },
	{ name = "sensor", parent = "turret", shape = "box", size = { 0.6, 0.4, 0.3 }, at = { 0, 12.0, -2.15 }, color = "glass" },

	{ name = "barrel1", parent = "turret", shape = "box", size = { 1.3, 1.3, 2.4 }, at = { -1.6, 11.2, -2.0 }, pivot = { -1.6, 11.2, -1.0 }, color = "hull" },
	{ name = "tube1", parent = "barrel1", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 2.0 }, at = { -1.6, 11.2, -4.0 }, color = "metal" },
	{ name = "lens1", parent = "barrel1", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 0.2 }, at = { -1.6, 11.2, -5.05 }, color = "glass" },
	{ name = "barrel2", parent = "turret", shape = "box", size = { 1.3, 1.3, 2.4 }, at = { 1.6, 11.2, -2.0 }, pivot = { 1.6, 11.2, -1.0 }, color = "hull" },
	{ name = "tube2", parent = "barrel2", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 2.0 }, at = { 1.6, 11.2, -4.0 }, color = "metal" },
	{ name = "lens2", parent = "barrel2", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 0.2 }, at = { 1.6, 11.2, -5.05 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_twin_guard",
	visualPieces = { "barrel1", "barrel2" },
	parts = parts,
	attachments = {
		{ name = "muzzle1", parent = "barrel1", at = { -1.6, 11.2, -5.2 } },
		{ name = "muzzle2", parent = "barrel2", at = { 1.6, 11.2, -5.2 } },
	},
}
