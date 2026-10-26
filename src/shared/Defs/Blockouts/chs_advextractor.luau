--!strict
-- Deep Excavator (Chaos, T2, footprint 2; the user 2026-10-26: "T2 of the
-- T1 extractor must be the same size, they should look like an upgrade
-- version"): the T1 Excavator upgraded in place on its 2 x 2 deposit patch
-- (S-108). The same slab, platform and four-legged pyramid derrick, but
-- taller with two tiers of bracing, armor plates at the feet and spikes, a
-- heavier head with a lamp; a thicker drill (`drill`, client-turned) with
-- four glowing bands, two engine drums instead of one, fuel tanks. About 15
-- studs tall to the T1's 8. Chaos reads crude and exposed (M-14). Model
-- space, forward = -Z.

local H = 13 -- the derrick's height under the head
local FOOT, TOP = 6.2, 1.8 -- the legs' offset from the centre at the ground and at the top

local parts = {
	{ name = "base", shape = "box", size = { 15.6, 0.6, 15.6 }, at = { 0, 0.3, 0 }, color = "dark" },
	{ name = "platform", parent = "base", shape = "box", size = { 12, 0.6, 12 }, at = { 0, 0.9, 0 }, color = "hull" },
	{ name = "grate", parent = "base", shape = "box", size = { 6, 0.08, 6 }, at = { 0, 1.24, 0 }, color = "metal" },
	{ name = "teamF", parent = "base", shape = "box", size = { 4, 0.08, 1.6 }, at = { -3, 1.24, -5 }, color = "team" },
	{ name = "teamB", parent = "base", shape = "box", size = { 4, 0.08, 1.6 }, at = { 3, 1.24, 5 }, color = "team" },
	{ name = "head", parent = "base", shape = "box", size = { 4.6, 1.8, 4.6 }, at = { 0, H + 0.9, 0 }, color = "hull" },
	{ name = "headTeam", parent = "base", shape = "box", size = { 3, 0.1, 3 }, at = { 0, H + 1.85, 0 }, color = "team" },
	{ name = "headSlit", parent = "base", shape = "box", size = { 3, 0.3, 0.1 }, at = { 0, H + 1.1, -2.35 }, color = "glass" },
	{ name = "lamp", parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { 0, H + 2.2, 0 }, color = "glass" },
	-- two engine drums (the T1 has one) and fuel tanks
	{ name = "drumA", parent = "base", shape = "cylinder", axis = "z", size = { 3.2, 3.2, 4.4 }, at = { 5.4, 2.8, 2.6 }, color = "dark" },
	{ name = "drumB", parent = "base", shape = "cylinder", axis = "z", size = { 3.2, 3.2, 4.4 }, at = { -5.4, 2.8, 2.6 }, color = "dark" },
	{ name = "drumTeam", parent = "base", shape = "box", size = { 2, 0.08, 3 }, at = { 5.4, 4.45, 2.6 }, color = "team" },
	{ name = "fuelA", parent = "base", shape = "cylinder", axis = "y", size = { 1.6, 3, 1.6 }, at = { -5.6, 2.7, -4.4 }, color = "metal" },
	{ name = "fuelB", parent = "base", shape = "cylinder", axis = "y", size = { 1.6, 3, 1.6 }, at = { 5.6, 2.7, -4.4 }, color = "metal" },
	{ name = "hazardF", parent = "base", shape = "box", size = { 5, 0.06, 0.6 }, at = { 0, 0.63, -7.2 }, color = "hazard" },
}
local function half(y: number): number -- the derrick's half-width at height y
	return FOOT - (FOOT - TOP) * (y - 1.2) / (H - 1.2)
end
for i, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
	local x0, z0, x1, z1 = c[1] * FOOT, c[2] * FOOT, c[1] * TOP, c[2] * TOP
	local dy = H - 1.2
	local len = math.sqrt((x1 - x0) ^ 2 + dy * dy + (z1 - z0) ^ 2)
	table.insert(parts, { name = `leg{i}`, parent = "base", shape = "box", size = { 0.6, len, 0.6 }, at = { (x0 + x1) / 2, 1.2 + dy / 2, (z0 + z1) / 2 }, rot = { math.deg(math.atan2(z1 - z0, dy)), 0, -math.deg(math.atan2(x1 - x0, dy)) }, color = "dark" })
	table.insert(parts, { name = `foot{i}`, parent = "base", shape = "box", size = { 1.6, 1.2, 1.6 }, at = { x0, 1.8, z0 }, color = "metal" })
	table.insert(parts, { name = `plate{i}`, parent = "base", shape = "wedge", size = { 2.4, 2.4, 0.4 }, at = { x0 * 0.92, 3.0, z0 * 0.92 }, rot = { 0, math.deg(math.atan2(c[1], c[2])) + 180, 0 }, color = if i % 2 == 0 then "team" else "metal" })
	table.insert(parts, { name = `spike{i}`, parent = "base", shape = "wedge", size = { 0.4, 1.6, 0.8 }, at = { x0, 3.2, z0 }, color = "metal" })
end
for tier, y in { 5.2, 9.4 } do -- two tiers of bracing round the derrick
	local w = half(y)
	for k, s in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
		local along = if s[1] == 0 then { 2 * w, 0.35, 0.35 } else { 0.35, 0.35, 2 * w }
		table.insert(parts, { name = `brace{tier}{k}`, parent = "base", shape = "box", size = along, at = { s[1] * w, y, s[2] * w }, color = "metal" })
	end
end
-- the drill: client-turned, with its glowing bands
table.insert(parts, { name = "drill", parent = "base", shape = "cylinder", axis = "y", size = { 2.2, H - 1.4, 2.2 }, at = { 0, 1.2 + (H - 1.4) / 2, 0 }, color = "metal", anim = { motion = "turn", axis = { 0, 1, 0 } } })
for k, y in { 2.6, 5.2, 7.8, 10.4 } do
	table.insert(parts, { name = `band{k}`, parent = "drill", shape = "cylinder", axis = "y", size = { 2.7, 0.4, 2.7 }, at = { 0, y, 0 }, color = "glass" })
end

return {
	id = "chs_advextractor",
	parts = parts,
}
