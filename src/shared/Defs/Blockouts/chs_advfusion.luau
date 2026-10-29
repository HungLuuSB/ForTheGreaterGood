--!strict
-- Great Hellforge (Chaos advanced fusion plant, T2, footprint 6; S-209, BAR
-- corafus): a squat stepped block ringed with heavy buttresses, a deep cup
-- holding a huge bare glowing sphere under a crude triple-pipe arch with
-- clamp blocks, hoses down to the slab, team plates. It goes up like a
-- small nuke. Model space, forward = -Z.

local CY = 18 -- the sphere's centre
local RA = 10.8 -- the arch's radius
local ARCH = math.rad(-30) -- the arch's plane, turned from the X axis

local parts: { any } = {
	{ name = "base", shape = "box", size = { 47.6, 1, 47.6 }, at = { 0, 0.5, 0 }, color = "dark" },
	{ name = "block", parent = "base", shape = "box", size = { 29.2, 5, 29.2 }, at = { 0, 3.5, 0 }, color = "hull" },
	{ name = "cupFoot", parent = "base", shape = "cylinder", axis = "y", size = { 15.2, 2, 15.2 }, at = { 0, 7, 0 }, color = "metal" },
	{ name = "cup", parent = "base", shape = "cylinder", axis = "y", size = { 20.8, 3.6, 20.8 }, at = { 0, 9.8, 0 }, color = "hull" },
	{ name = "rim", parent = "base", shape = "cylinder", axis = "y", size = { 21.2, 0.7, 21.2 }, at = { 0, 11.6, 0 }, color = "team" },
	{ name = "core", parent = "base", shape = "ball", size = { 18, 18, 18 }, at = { 0, CY, 0 }, color = "glass", anim = { motion = "pulse", axis = { 0, 1, 0 } } },
	{ name = "ramp", parent = "base", shape = "wedge", size = { 7, 6.4, 8 }, at = { 0, 4.2, -19 }, color = "hull" },
	{ name = "teamA", parent = "base", shape = "box", size = { 5, 0.1, 5 }, at = { -19, 1.05, -12.6 }, color = "team" },
	{ name = "teamB", parent = "base", shape = "box", size = { 5, 0.1, 5 }, at = { 19, 1.05, 12.6 }, color = "team" },
	{ name = "hazard", parent = "base", shape = "box", size = { 16, 0.06, 0.9 }, at = { 0, 1.03, -22.6 }, color = "hazard" },
}
local ax, az = math.cos(ARCH), math.sin(ARCH)
local yaw = -math.deg(ARCH)
for i = 0, 6 do
	local phi = math.rad(-25 + 230 / 6 * i)
	local x, y = math.cos(phi) * RA, CY + math.sin(phi) * RA
	table.insert(parts, { name = `arch{i}`, parent = "base", shape = "box", size = { 3.4, 1.6, 3.4 }, at = { ax * x, y, az * x }, rot = { 0, yaw, math.deg(phi) + 90 }, color = if i % 2 == 0 then "hull" else "dark" })
end
for i, d in { 30, 90, 150, 210, 330 } do
	local t = math.rad(d)
	table.insert(parts, { name = `buttress{i}`, parent = "base", shape = "box", size = { 6.4, 7, 6 }, at = { math.cos(t) * 18.5, 4.5, math.sin(t) * 18.5 }, rot = { 0, -d, 0 }, color = "hull" })
end

return {
	id = "chs_advfusion",
	parts = parts,
}
