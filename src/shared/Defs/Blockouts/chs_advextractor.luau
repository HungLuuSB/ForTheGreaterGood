--!strict
-- Deep Excavator (Chaos, T2, footprint 4; F6 / S-184, 2026-10-26: built
-- centred over the player's own T1 extractor on its 2 x 2 deposit patch,
-- which it replaces when finished, S-108): a crude derrick astride the
-- deposit. Four splayed lattice legs from the corners, outside the T1's
-- 16-stud footprint, braced and meeting at a platform 12 studs up (clear
-- over the T1 while it works on underneath); through it one huge drill
-- (`drill`, client-turned) from the head down into the patch with a glowing
-- band; engines, fuel tanks and an exhaust on the pad, a slat cage, team
-- plates. Chaos reads crude and exposed (M-14). Model space, forward = -Z.

local PY = 12 -- the platform's underside
local L = 12.4 -- the legs' feet, offset from the centre

local parts = {
	{ name = "base", shape = "box", size = { 30, 0.5, 30 }, at = { 0, 0.25, 0 }, color = "dark" },
	{ name = "patch", parent = "base", shape = "cylinder", axis = "y", size = { 14, 0.1, 14 }, at = { 0, 0.55, 0 }, color = "glass" },
	{ name = "platform", parent = "base", shape = "box", size = { 12, 1.2, 12 }, at = { 0, PY + 0.6, 0 }, color = "hull" },
	{ name = "platformTeam", parent = "base", shape = "box", size = { 0.1, 0.8, 6 }, at = { -6.05, PY + 0.6, 0 }, color = "team" },
	{ name = "platformTeam2", parent = "base", shape = "box", size = { 0.1, 0.8, 6 }, at = { 6.05, PY + 0.6, 0 }, color = "team" },
	{ name = "railF", parent = "base", shape = "box", size = { 12, 0.3, 0.3 }, at = { 0, PY + 2.2, -5.85 }, color = "dark" },
	{ name = "railB", parent = "base", shape = "box", size = { 12, 0.3, 0.3 }, at = { 0, PY + 2.2, 5.85 }, color = "dark" },
	{ name = "drill", parent = "base", shape = "cylinder", axis = "y", size = { 3.4, PY + 9, 3.4 }, at = { 0, (PY + 9) / 2 + 0.5, 0 }, color = "metal", anim = { motion = "turn", axis = { 0, 1, 0 } } },
	{ name = "glow", parent = "base", shape = "cylinder", axis = "y", size = { 3.7, 0.5, 3.7 }, at = { 0, 3.2, 0 }, color = "glass" },
	{ name = "head", parent = "base", shape = "box", size = { 5, 2.4, 5 }, at = { 0, PY + 10.2, 0 }, color = "hull" },
	{ name = "headLamp", parent = "base", shape = "box", size = { 0.7, 0.7, 0.7 }, at = { 0, PY + 11.8, 0 }, color = "glass" },
	{ name = "engineA", parent = "base", shape = "box", size = { 4, 3.4, 5 }, at = { 9, 2.2, 3 }, color = "hull" },
	{ name = "engineB", parent = "base", shape = "box", size = { 4, 3.4, 5 }, at = { 9, 2.2, -4 }, color = "hull" },
	{ name = "exhaust", parent = "base", shape = "cylinder", axis = "y", size = { 0.9, 5, 0.9 }, at = { 10.4, 6.3, 4.6 }, color = "dark" },
	{ name = "fuelA", parent = "base", shape = "cylinder", axis = "y", size = { 3, 5, 3 }, at = { -9.6, 3, -3.6 }, color = "metal" },
	{ name = "fuelB", parent = "base", shape = "cylinder", axis = "y", size = { 3, 5, 3 }, at = { -9.6, 3, 3.6 }, color = "metal" },
	{ name = "teamA", parent = "base", shape = "box", size = { 5, 0.1, 5 }, at = { -10.5, 0.55, -11 }, color = "team" },
	{ name = "cageF", parent = "base", shape = "box", size = { 26, 0.25, 0.25 }, at = { 0, 2.4, -13.8 }, color = "dark" },
	{ name = "cageB", parent = "base", shape = "box", size = { 26, 0.25, 0.25 }, at = { 0, 2.4, 13.8 }, color = "dark" },
}
for i, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do -- splayed lattice legs, foot at the corner, top under the platform
	local x0, z0, x1, z1 = c[1] * L, c[2] * L, c[1] * 5, c[2] * 5
	local dx, dz = x1 - x0, z1 - z0
	local len = math.sqrt(dx * dx + PY * PY + dz * dz)
	local tiltX = math.deg(math.atan2(dz, PY)) -- leans toward the centre in z
	local tiltZ = -math.deg(math.atan2(dx, PY)) -- and in x
	table.insert(parts, { name = `leg{i}`, parent = "base", shape = "box", size = { 1.2, len, 1.2 }, at = { (x0 + x1) / 2, PY / 2 + 0.5, (z0 + z1) / 2 }, rot = { tiltX, 0, tiltZ }, color = "dark" })
end
for i, s in { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } } do -- a brace ring half way up
	local w = if s[1] == 0 then 17 else 0.5
	local d = if s[1] == 0 then 0.5 else 17
	table.insert(parts, { name = `brace{i}`, parent = "base", shape = "box", size = { w, 0.5, d }, at = { s[1] * 8.6, PY / 2, s[2] * 8.6 }, color = "metal" })
end

return {
	id = "chs_advextractor",
	parts = parts,
}
