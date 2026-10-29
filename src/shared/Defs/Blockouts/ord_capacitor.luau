--!strict
-- Capacitor Bank (Order energy storage, T1, footprint 2; S-209, BAR
-- armestor): an upright octagonal stack of glowing cells held by four
-- corner pillars with team panels, four armored feet, a glowing charge
-- port on top. Model space, forward = -Z (docs/contracts/rig.md).

local parts: { any } = {
	{ name = "base", shape = "box", size = { 15.6, 0.6, 15.6 }, at = { 0, 0.3, 0 }, color = "hull" },
	{ name = "stack", parent = "base", shape = "cylinder", axis = "y", size = { 7.6, 7.4, 7.6 }, at = { 0, 4.7, 0 }, color = "dark" },
	{ name = "cells", parent = "base", shape = "cylinder", axis = "y", size = { 7.7, 4.6, 7.7 }, at = { 0, 4.9, 0 }, color = "glass" },
	{ name = "cap", parent = "base", shape = "cylinder", axis = "y", size = { 8.2, 0.6, 8.2 }, at = { 0, 8.7, 0 }, color = "hull" },
	{ name = "port", parent = "base", shape = "cylinder", axis = "y", size = { 3.2, 0.2, 3.2 }, at = { 0, 9.1, 0 }, color = "glass" },
}
for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
	local x, z = c[1] * 3.25, c[2] * 3.25
	local yaw = if c[1] == c[2] then -45 else 45
	table.insert(parts, { name = `pillar{#parts}`, parent = "base", shape = "box", size = { 2.5, 9.0, 1.8 }, at = { x, 5.1, z }, rot = { 0, yaw, 0 }, color = "hull" })
	table.insert(parts, { name = `pillarTeam{#parts}`, parent = "base", shape = "box", size = { 1.4, 5.2, 0.1 }, at = { c[1] * 3.9, 5.0, c[2] * 3.9 }, rot = { 0, yaw, 0 }, color = "team" })
end
for _, d in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
	table.insert(parts, { name = `foot{#parts}`, parent = "base", shape = "box", size = { 2.6 + math.abs(d[1]) * 1.0, 1.0, 2.6 + math.abs(d[2]) * 1.0 }, at = { d[1] * 5.4, 1.1, d[2] * 5.4 }, color = "hull" })
	table.insert(parts, { name = `footTeam{#parts}`, parent = "base", shape = "box", size = { 1.8, 0.1, 1.8 }, at = { d[1] * 6.2, 1.65, d[2] * 6.2 }, color = "team" })
end

return {
	id = "ord_capacitor",
	parts = parts,
}
