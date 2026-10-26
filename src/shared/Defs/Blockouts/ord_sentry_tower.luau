--!strict
-- Sentry (Order laser tower, T1, footprint 2; S-157; the user's reference
-- 2026-10-24: a tall slim laser tower; F18 2026-10-26: "turret should stand
-- high, proud, tower above others", so taller and heavier, top ~20 studs,
-- under the T2 towers' ~24): a skirt of eight armored petals round a
-- footing, a tall slim column with a lit band, and on top the `turret`: an
-- upright box head carrying one red laser emitter offset to the left, a
-- sensor and a team panel. The def turns `turret` and pitches `barrel`
-- (the emitter's mount, -60..+60 degrees); `muzzle` at the lens.
-- Order reads clean and heavy (M-14). Model space, forward = -Z.

local RING = 16.0 -- top of the column, where the head turns
local EY = RING + 1.6 -- emitter height

local parts = {
	{ name = "base", shape = "cylinder", axis = "y", size = { 9.0, 1.2, 9.0 }, at = { 0, 0.6, 0 }, color = "dark" },
	{ name = "footing", parent = "base", shape = "cylinder", axis = "y", size = { 5.6, 3.2, 5.6 }, at = { 0, 2.8, 0 }, color = "hull" },
	{ name = "column", parent = "base", shape = "box", size = { 2.6, RING - 4.8, 2.6 }, at = { 0, 4.4 + (RING - 4.8) / 2, 0 }, color = "hull" },
	{ name = "columnSpine", parent = "base", shape = "box", size = { 0.6, RING - 6, 0.3 }, at = { 0, 4.4 + (RING - 4.8) / 2, 1.42 }, color = "dark" },
	{ name = "band", parent = "base", shape = "box", size = { 2.7, 0.35, 2.7 }, at = { 0, 7.2, 0 }, color = "glass" },
	{ name = "band2", parent = "base", shape = "box", size = { 2.7, 0.35, 2.7 }, at = { 0, RING - 3.2, 0 }, color = "glass" },
	{ name = "collar", parent = "base", shape = "cylinder", axis = "y", size = { 3.8, 0.8, 3.8 }, at = { 0, RING - 0.4, 0 }, color = "dark" },
}
for k = 0, 7 do -- the armored skirt
	local a = math.rad(k * 45 + 22.5)
	local team = k % 2 == 0
	table.insert(parts, { name = `petal{k}`, parent = "base", shape = "box", size = { 3.4, 2.8, 0.8 }, at = { math.sin(a) * 4.8, 2.0, math.cos(a) * 4.8 }, rot = { -18, math.deg(a), 0 }, color = if team then "team" else "hull" })
end
for _, p in {
	{ name = "turret", parent = "base", shape = "box", size = { 3.2, 4.2, 3.6 }, at = { 0.4, RING + 2.2, 0.2 }, pivot = { 0, RING, 0 }, color = "hull" },
	{ name = "turretTeam", parent = "turret", shape = "box", size = { 0.08, 2.4, 2.4 }, at = { 2.04, RING + 2.4, 0.2 }, color = "team" },
	{ name = "sensor", parent = "turret", shape = "box", size = { 0.8, 0.8, 0.1 }, at = { 1.0, RING + 3.4, -1.62 }, color = "glass" },
	{ name = "barrel", parent = "turret", shape = "box", size = { 1.6, 1.6, 1.6 }, at = { -1.6, EY, -1.0 }, pivot = { -1.6, EY, -1.0 }, color = "dark" },
	{ name = "emitter", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.0, 1.0, 4.0 }, at = { -1.6, EY, -3.6 }, color = "metal" },
	{ name = "coil", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.4, 1.4, 0.5 }, at = { -1.6, EY, -4.6 }, color = "dark" },
	{ name = "lens", parent = "barrel", shape = "cylinder", axis = "z", size = { 0.8, 0.8, 0.25 }, at = { -1.6, EY, -5.7 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_sentry_tower",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { -1.6, EY, -5.9 } },
	},
}
