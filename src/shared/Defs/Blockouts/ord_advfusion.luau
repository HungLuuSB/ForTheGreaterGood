--!strict
-- Advanced Fusion Reactor (Order, T2, footprint 6; S-209, BAR armafus): a
-- stepped armored ziggurat holding a huge glowing containment sphere in a
-- cradle, gripped by four massive claw pylons on the diagonals; an intake
-- gate with coolant tubes at the front, team plates on the lower deck. It
-- goes up like a small nuke. Model space, forward = -Z.

local CY = 20 -- the sphere's centre

local parts: { any } = {
	{ name = "base", shape = "box", size = { 47.6, 1.2, 47.6 }, at = { 0, 0.6, 0 }, color = "dark" },
	{ name = "tier1", parent = "base", shape = "box", size = { 40.8, 3.8, 40.8 }, at = { 0, 3.1, 0 }, color = "hull" },
	{ name = "tier2", parent = "base", shape = "box", size = { 28.4, 4.6, 28.4 }, at = { 0, 7.3, 0 }, color = "hull" },
	{ name = "pedestal", parent = "base", shape = "cylinder", axis = "y", size = { 12.8, 3.2, 12.8 }, at = { 0, 11.2, 0 }, color = "metal" },
	{ name = "cup", parent = "base", shape = "cylinder", axis = "y", size = { 13.2, 1.4, 13.2 }, at = { 0, 13.5, 0 }, color = "dark" },
	{ name = "core", parent = "base", shape = "ball", size = { 15.2, 15.2, 15.2 }, at = { 0, CY, 0 }, color = "glass", anim = { motion = "pulse", axis = { 0, 1, 0 } } },
	{ name = "gate", parent = "base", shape = "box", size = { 9.2, 8.4, 3.4 }, at = { 0, 5.4, -16.1 }, color = "metal" },
	{ name = "gateGlow", parent = "base", shape = "box", size = { 7.4, 0.3, 0.1 }, at = { 0, 7.9, -17.9 }, color = "glass" },
}
for i, s in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
	table.insert(parts, { name = `team{i}`, parent = "base", shape = "box", size = { s[1] ~= 0 and 3 or 9, 0.1, s[1] ~= 0 and 9 or 3 }, at = { s[1] * 16.6, 5.05, s[2] * 16.6 }, color = "team" })
end
for i, d in { { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } } do
	local x, z = d[1] * 12.5, d[2] * 12.5 -- the pylon at radius ~17.7 on the diagonal
	local yaw = math.deg(math.atan2(-d[2], d[1])) -- the pylon's width across the diagonal
	table.insert(parts, { name = `pylon{i}`, parent = "base", shape = "box", size = { 6.4, 15, 6.4 }, at = { x, 8.7, z }, rot = { 0, yaw + 45, 0 }, color = "hull" })
	table.insert(parts, { name = `arm{i}`, parent = "base", shape = "box", size = { 4.6, 12, 4.6 }, at = { d[1] * 10.6, 21, d[2] * 10.6 }, rot = { 0, yaw + 45, 0 }, color = "hull" })
	table.insert(parts, { name = `finger{i}`, parent = "base", shape = "box", size = { 4, 2.4, 4 }, at = { d[1] * 7.4, 26.8, d[2] * 7.4 }, rot = { 0, yaw + 45, 0 }, color = "metal" })
	table.insert(parts, { name = `seam{i}`, parent = "base", shape = "box", size = { 0.3, 9, 0.3 }, at = { d[1] * 12.4, 21, d[2] * 12.4 }, color = "glass" })
end

return {
	id = "ord_advfusion",
	parts = parts,
}
