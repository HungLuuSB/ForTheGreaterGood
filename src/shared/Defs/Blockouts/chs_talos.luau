--!strict
-- Talos (Chaos artillery battery, T1, footprint 2; S-157; the user's
-- reference 2026-10-24: a low wide battery with twin barrels and heavy side
-- pods): a squat armored emplacement with big angled armor pods at the
-- corners, the `turret` with a ridged slab housing, and the `barrel`
-- (pitch; up to 85 degrees for high-arc shells): two thick ribbed barrels
-- side by side, fired as one weapon. Modelled level; `muzzle` between the
-- mouths. Rugged and heavy (M-14). Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 10.6, 1.2, 10.6 }, at = { 0, 0.6, 0 }, color = "dark" },
	{ name = "emplacement", parent = "base", shape = "cylinder", axis = "y", size = { 7.6, 2.6, 7.6 }, at = { 0, 2.5, 0 }, color = "dark" },
}
for k = 0, 3 do -- heavy angled armor pods at the corners
	local a = math.rad(k * 90 + 45)
	table.insert(parts, { name = `pod{k}`, parent = "base", shape = "box", size = { 3.2, 2.8, 2.4 }, at = { math.sin(a) * 4.6, 2.2, math.cos(a) * 4.6 }, rot = { -12, math.deg(a), 0 }, color = if k < 2 then "team" else "metal" })
end
for _, p in {
	{ name = "turret", parent = "base", shape = "box", size = { 5.4, 2.6, 5.0 }, at = { 0, 5.0, 0.8 }, pivot = { 0, 3.8, 0 }, color = "hull" },
	{ name = "turretTeam", parent = "turret", shape = "box", size = { 3.0, 0.08, 1.8 }, at = { 0, 6.34, 2.2 }, color = "team" },

	{ name = "barrel", parent = "turret", shape = "box", size = { 4.2, 2.4, 4.6 }, at = { 0, 7.4, -0.2 }, pivot = { 0, 7.4, 0.6 }, color = "metal" },
	{ name = "ridgeL", parent = "barrel", shape = "box", size = { 0.5, 0.6, 4.4 }, at = { -1.6, 8.8, -0.2 }, color = "dark" },
	{ name = "ridgeR", parent = "barrel", shape = "box", size = { 0.5, 0.6, 4.4 }, at = { 1.6, 8.8, -0.2 }, color = "dark" },
	{ name = "gunL", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.1, 1.1, 4.6 }, at = { -1.0, 7.4, -4.6 }, color = "metal" },
	{ name = "gunR", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.1, 1.1, 4.6 }, at = { 1.0, 7.4, -4.6 }, color = "metal" },
	{ name = "ribL", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.4, 1.4, 0.4 }, at = { -1.0, 7.4, -3.6 }, color = "dark" },
	{ name = "ribR", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.4, 1.4, 0.4 }, at = { 1.0, 7.4, -3.6 }, color = "dark" },
	{ name = "mouthL", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.4, 1.4, 0.6 }, at = { -1.0, 7.4, -6.9 }, color = "dark" },
	{ name = "mouthR", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.4, 1.4, 0.6 }, at = { 1.0, 7.4, -6.9 }, color = "dark" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_talos",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 7.4, -7.3 } },
	},
}
