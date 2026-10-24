--!strict
-- Gauntlet (Order artillery battery, T1, footprint 2; S-157; the user's
-- reference 2026-10-24: a low wide battery with long twin barrels): a wide
-- octagonal emplacement with armored side panels and team plates, a low
-- turret ring, the boxy `turret` carrying the gun cradle, and the `barrel`
-- (pitch; up to 85 degrees for high-arc shells): two long barrels side by
-- side in one housing, fired as one weapon. Modelled level; `muzzle` between
-- the two mouths. Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "cylinder", axis = "y", size = { 11.4, 1.2, 11.4 }, at = { 0, 0.6, 0 }, color = "dark" },
	{ name = "emplacement", parent = "base", shape = "box", size = { 8.6, 2.4, 8.6 }, at = { 0, 2.4, 0 }, color = "hull" },
}
for k = 0, 3 do -- armored side panels with team plates
	local a = math.rad(k * 90 + 45)
	table.insert(parts, { name = `panel{k}`, parent = "base", shape = "box", size = { 4.0, 2.6, 0.8 }, at = { math.sin(a) * 5.0, 2.1, math.cos(a) * 5.0 }, rot = { -15, math.deg(a), 0 }, color = "team" })
end
for _, p in {
	{ name = "ring", parent = "base", shape = "cylinder", axis = "y", size = { 6.6, 0.6, 6.6 }, at = { 0, 3.9, 0 }, color = "metal" },

	{ name = "turret", parent = "base", shape = "box", size = { 5.6, 2.4, 5.4 }, at = { 0, 5.4, 0.6 }, pivot = { 0, 4.2, 0 }, color = "hull" },
	{ name = "turretTeam", parent = "turret", shape = "box", size = { 3.4, 0.08, 2.0 }, at = { 0, 6.64, 2.0 }, color = "team" },
	{ name = "cheekL", parent = "turret", shape = "box", size = { 0.6, 2.2, 3.2 }, at = { -2.4, 7.4, 0 }, color = "hull" },
	{ name = "cheekR", parent = "turret", shape = "box", size = { 0.6, 2.2, 3.2 }, at = { 2.4, 7.4, 0 }, color = "hull" },

	{ name = "barrel", parent = "turret", shape = "box", size = { 3.8, 2.0, 4.4 }, at = { 0, 7.6, -0.4 }, pivot = { 0, 7.6, 0.4 }, color = "hull" },
	{ name = "gunL", parent = "barrel", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 6.0 }, at = { -0.9, 7.6, -5.4 }, color = "metal" },
	{ name = "gunR", parent = "barrel", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 6.0 }, at = { 0.9, 7.6, -5.4 }, color = "metal" },
	{ name = "brakeL", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.2, 1.2, 0.8 }, at = { -0.9, 7.6, -8.4 }, color = "dark" },
	{ name = "brakeR", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.2, 1.2, 0.8 }, at = { 0.9, 7.6, -8.4 }, color = "dark" },
	{ name = "barrelTeam", parent = "barrel", shape = "box", size = { 2.4, 0.08, 2.6 }, at = { 0, 8.64, -0.4 }, color = "team" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_gauntlet",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 7.6, -8.9 } },
	},
}
