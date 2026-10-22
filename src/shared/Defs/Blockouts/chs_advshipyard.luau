--!strict
-- Advanced Drydock (Chaos, T2, footprint 5): piers on pilings, two lattice
-- tower cranes with long jibs (one per pier), a shed and fuel tanks at the
-- back, orange lights. Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 38, 0.6, 7 }, at = { 0, 0.3, 15.5 }, color = "dark" },
	{ name = "pierL", parent = "base", shape = "box", size = { 4.5, 1.2, 33 }, at = { -16.5, 1.4, -2 }, color = "hull" },
	{ name = "pierR", parent = "base", shape = "box", size = { 4.5, 1.2, 33 }, at = { 16.5, 1.4, -2 }, color = "hull" },
	{ name = "pierTeamL", parent = "base", shape = "box", size = { 3.4, 0.08, 8 }, at = { -16.5, 2.04, -12 }, color = "team" },
	{ name = "pierTeamR", parent = "base", shape = "box", size = { 3.4, 0.08, 8 }, at = { 16.5, 2.04, -12 }, color = "team" },
	{ name = "shed", parent = "base", shape = "box", size = { 16, 6, 6 }, at = { -4, 3.6, 15.5 }, color = "hull" },
	{ name = "tankA", parent = "base", shape = "cylinder", axis = "y", size = { 3, 4, 3 }, at = { 8, 2.6, 15.5 }, color = "metal" },
	{ name = "tankB", parent = "base", shape = "cylinder", axis = "y", size = { 3, 4, 3 }, at = { 12, 2.6, 15.5 }, color = "metal" },
	{ name = "lightL", parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { -16.5, 2.3, -18 }, color = "glass" },
	{ name = "lightR", parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { 16.5, 2.3, -18 }, color = "glass" },
}
for c, side in { -1, 1 } do
	local x0 = side * 16.5
	local z0 = if side < 0 then 4 else -6
	for i, d in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		table.insert(parts, { name = `tower{c}{i}`, parent = "base", shape = "box", size = { 0.5, 13, 0.5 }, at = { x0 + d[1], 8.5, z0 + d[2] }, color = "dark" })
	end
	table.insert(parts, { name = `jib{c}`, parent = "base", shape = "box", size = { 22, 0.8, 1 }, at = { x0 - side * 9, 15.2, z0 }, color = "metal" })
	table.insert(parts, { name = `jibTeam{c}`, parent = "base", shape = "box", size = { 10, 0.08, 0.8 }, at = { x0 - side * 11, 15.64, z0 }, color = "team" })
	table.insert(parts, { name = `jibLight{c}`, parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { x0 - side * 19.5, 15.8, z0 }, color = "glass" })
end
-- T2 signature (T1 vs T2 check, 2026-10-22): one giant hammerhead crane on
-- the shore, its jib reaching across the whole slip
for i, d in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
	table.insert(parts, { name = `giantLeg{i}`, parent = "base", shape = "box", size = { 0.6, 24, 0.6 }, at = { 8 + d[1] * 1.4, 12.6, 11.3 + d[2] * 1.4 }, color = "dark" })
end
table.insert(parts, { name = "giantCab", parent = "base", shape = "box", size = { 3.6, 1.6, 3.6 }, at = { 8, 25.4, 11.3 }, color = "hull" })
table.insert(parts, { name = "giantJib", parent = "base", shape = "box", size = { 34, 1.2, 1.4 }, at = { -4, 26.6, 11.3 }, color = "metal" })
table.insert(parts, { name = "giantJibTeam", parent = "base", shape = "box", size = { 14, 0.08, 1.1 }, at = { -8, 27.24, 11.3 }, color = "team" })
table.insert(parts, { name = "giantWeight", parent = "base", shape = "box", size = { 3, 2.2, 2.2 }, at = { 12.5, 25.6, 11.3 }, color = "dark" })
table.insert(parts, { name = "giantHook", parent = "base", shape = "box", size = { 0.2, 9, 0.2 }, at = { -14, 21.6, 11.3 }, color = "dark" })
table.insert(parts, { name = "giantLight", parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { -20.6, 27.5, 11.3 }, color = "glass" })
for i = 0, 4 do
	local z = -16 + i * 7.5
	for _, x in { -16.5, 16.5 } do
		table.insert(parts, { name = `pile{i}{x > 0 and "R" or "L"}`, parent = "base", shape = "cylinder", axis = "y", size = { 0.8, 1.4, 0.8 }, at = { x, 0.4, z }, color = "dark" })
	end
end

return { id = "chs_advshipyard", parts = parts }
