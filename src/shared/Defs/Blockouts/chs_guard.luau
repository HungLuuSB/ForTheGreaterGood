--!strict
-- Guard (Chaos laser tower, T1, footprint 2; S-157; the user's reference
-- 2026-10-24: a tall laser tower on an armored skirt; F18 2026-10-26: "turret
-- should stand high, proud, tower above others", so taller and heavier, top
-- ~18 studs): a skirt of heavy angled armor plates, a stout round column
-- with a vent, and on top the `turret`: a rounded head with one stubby red
-- laser tube and a ribbed shroud (`barrel`, pitched -60..+60 degrees). The
-- def turns `turret`; `muzzle` at the lens. Rugged and heavier than the
-- Sentry (M-14). Model space, forward = -Z.

local RING = 14.4 -- top of the column, where the head turns
local EY = RING + 1.6 -- tube height

local parts = {
	{ name = "base", shape = "cylinder", axis = "y", size = { 9.6, 1.2, 9.6 }, at = { 0, 0.6, 0 }, color = "dark" },
	{ name = "footing", parent = "base", shape = "cylinder", axis = "y", size = { 6.0, 3.0, 6.0 }, at = { 0, 2.7, 0 }, color = "dark" },
	{ name = "column", parent = "base", shape = "cylinder", axis = "y", size = { 3.8, RING - 4.2, 3.8 }, at = { 0, 4.2 + (RING - 4.2) / 2, 0 }, color = "hull" },
	{ name = "vent", parent = "base", shape = "box", size = { 1.4, 2.0, 0.2 }, at = { 0, 10.0, -1.9 }, color = "glass" },
	{ name = "band1", parent = "base", shape = "cylinder", axis = "y", size = { 4.1, 0.5, 4.1 }, at = { 0, 5.6, 0 }, color = "metal" },
	{ name = "band2", parent = "base", shape = "cylinder", axis = "y", size = { 4.1, 0.5, 4.1 }, at = { 0, RING - 1.6, 0 }, color = "metal" },
}
for k = 0, 5 do -- the heavy angled skirt
	local a = math.rad(k * 60 + 30)
	table.insert(parts, { name = `plate{k}`, parent = "base", shape = "box", size = { 4.2, 3.0, 1.0 }, at = { math.sin(a) * 5.0, 2.2, math.cos(a) * 5.0 }, rot = { -24, math.deg(a), 0 }, color = if k % 2 == 0 then "team" else "metal" })
end
for _, p in {
	{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 4.4, 3.0, 4.4 }, at = { 0, RING + 1.5, 0.2 }, pivot = { 0, RING, 0 }, color = "hull" },
	{ name = "roofTeam", parent = "turret", shape = "box", size = { 2.6, 0.08, 2.2 }, at = { 0, RING + 3.04, 0.4 }, color = "team" },
	{ name = "barrel", parent = "turret", shape = "box", size = { 2.0, 1.8, 2.8 }, at = { 0, EY + 0.1, -2.0 }, pivot = { 0, EY, -1.0 }, color = "hull" },
	{ name = "rib", parent = "barrel", shape = "box", size = { 2.1, 0.24, 2.2 }, at = { 0, EY + 0.85, -2.0 }, color = "dark" },
	{ name = "tube", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.1, 1.1, 3.0 }, at = { 0, EY, -4.6 }, color = "metal" },
	{ name = "lens", parent = "barrel", shape = "cylinder", axis = "z", size = { 0.8, 0.8, 0.25 }, at = { 0, EY, -6.2 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_guard",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, EY, -6.4 } },
	},
}
