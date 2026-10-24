--!strict
-- Sentry (Order laser tower, T1, footprint 2; S-157; the user's reference
-- 2026-10-24: a tall slim laser tower): a skirt of eight armored petals round
-- a footing, a tall slim column with a lit band, and on top the `turret`: an
-- upright box head carrying one red laser emitter offset to the left, a
-- sensor and a team panel. The def turns `turret` and pitches `barrel`
-- (the emitter's mount, -60..+60 degrees); `muzzle` at the lens.
-- Order reads clean and heavy (M-14). Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "cylinder", axis = "y", size = { 6.4, 1.2, 6.4 }, at = { 0, 0.6, 0 }, color = "dark" },
	{ name = "footing", parent = "base", shape = "cylinder", axis = "y", size = { 4.2, 2.6, 4.2 }, at = { 0, 2.3, 0 }, color = "hull" },
	{ name = "column", parent = "base", shape = "box", size = { 2.0, 7.6, 2.0 }, at = { 0, 7.4, 0 }, color = "hull" },
	{ name = "columnSpine", parent = "base", shape = "box", size = { 0.5, 6.8, 0.3 }, at = { 0, 7.4, 1.1 }, color = "dark" },
	{ name = "band", parent = "base", shape = "box", size = { 2.1, 0.3, 2.1 }, at = { 0, 5.4, 0 }, color = "glass" },
	{ name = "collar", parent = "base", shape = "cylinder", axis = "y", size = { 2.8, 0.6, 2.8 }, at = { 0, 11.0, 0 }, color = "dark" },
}
for k = 0, 7 do -- the armored skirt
	local a = math.rad(k * 45 + 22.5)
	local team = k % 2 == 0
	table.insert(parts, { name = `petal{k}`, parent = "base", shape = "box", size = { 2.6, 2.2, 0.7 }, at = { math.sin(a) * 3.6, 1.7, math.cos(a) * 3.6 }, rot = { -18, math.deg(a), 0 }, color = if team then "team" else "hull" })
end
for _, p in {
	{ name = "turret", parent = "base", shape = "box", size = { 2.4, 3.2, 2.8 }, at = { 0.3, 13.0, 0.2 }, pivot = { 0, 11.3, 0 }, color = "hull" },
	{ name = "turretTeam", parent = "turret", shape = "box", size = { 0.08, 1.8, 1.8 }, at = { 1.54, 13.2, 0.2 }, color = "team" },
	{ name = "sensor", parent = "turret", shape = "box", size = { 0.6, 0.6, 0.1 }, at = { 0.8, 14.0, -1.25 }, color = "glass" },
	{ name = "barrel", parent = "turret", shape = "box", size = { 1.2, 1.2, 1.2 }, at = { -1.2, 12.6, -0.8 }, pivot = { -1.2, 12.6, -0.8 }, color = "dark" },
	{ name = "emitter", parent = "barrel", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 3.0 }, at = { -1.2, 12.6, -2.6 }, color = "metal" },
	{ name = "lens", parent = "barrel", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 0.2 }, at = { -1.2, 12.6, -4.15 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_sentry_tower",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { -1.2, 12.6, -4.3 } },
	},
}
