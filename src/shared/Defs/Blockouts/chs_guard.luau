--!strict
-- Guard (Chaos laser tower, T1, footprint 2; S-157; the user's reference
-- 2026-10-24: a tall laser tower on an armored skirt): a skirt of heavy
-- angled armor plates, a stout octagonal column with a vent, and on top the
-- `turret`: a rounded head with one stubby red laser tube and a ribbed
-- shroud (`barrel`, pitched -60..+60 degrees). The def turns `turret`;
-- `muzzle` at the lens. Rugged and heavier than the Sentry (M-14). Model
-- space, forward = -Z.

local parts = {
	{ name = "base", shape = "cylinder", axis = "y", size = { 7.0, 1.2, 7.0 }, at = { 0, 0.6, 0 }, color = "dark" },
	{ name = "footing", parent = "base", shape = "cylinder", axis = "y", size = { 4.6, 2.4, 4.6 }, at = { 0, 2.2, 0 }, color = "dark" },
	{ name = "column", parent = "base", shape = "cylinder", axis = "y", size = { 3.0, 6.6, 3.0 }, at = { 0, 6.7, 0 }, color = "hull" },
	{ name = "vent", parent = "base", shape = "box", size = { 1.2, 1.6, 0.2 }, at = { 0, 7.4, -1.5 }, color = "glass" },
	{ name = "band1", parent = "base", shape = "cylinder", axis = "y", size = { 3.3, 0.4, 3.3 }, at = { 0, 4.4, 0 }, color = "metal" },
	{ name = "band2", parent = "base", shape = "cylinder", axis = "y", size = { 3.3, 0.4, 3.3 }, at = { 0, 9.4, 0 }, color = "metal" },
}
for k = 0, 5 do -- the heavy angled skirt
	local a = math.rad(k * 60 + 30)
	table.insert(parts, { name = `plate{k}`, parent = "base", shape = "box", size = { 3.4, 2.4, 0.8 }, at = { math.sin(a) * 3.8, 1.8, math.cos(a) * 3.8 }, rot = { -24, math.deg(a), 0 }, color = if k % 2 == 0 then "team" else "metal" })
end
for _, p in {
	{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 3.4, 2.4, 3.4 }, at = { 0, 11.2, 0.2 }, pivot = { 0, 10.0, 0 }, color = "hull" },
	{ name = "roofTeam", parent = "turret", shape = "box", size = { 2.0, 0.08, 1.8 }, at = { 0, 12.44, 0.4 }, color = "team" },
	{ name = "barrel", parent = "turret", shape = "box", size = { 1.6, 1.4, 2.2 }, at = { 0, 11.4, -1.6 }, pivot = { 0, 11.3, -0.8 }, color = "hull" },
	{ name = "rib", parent = "barrel", shape = "box", size = { 1.7, 0.2, 1.8 }, at = { 0, 12.0, -1.6 }, color = "dark" },
	{ name = "tube", parent = "barrel", shape = "cylinder", axis = "z", size = { 0.8, 0.8, 2.4 }, at = { 0, 11.3, -3.6 }, color = "metal" },
	{ name = "lens", parent = "barrel", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 0.2 }, at = { 0, 11.3, -4.85 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_guard",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 11.3, -5.0 } },
	},
}
