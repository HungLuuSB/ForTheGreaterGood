--!strict
-- Drydock (Chaos shipyard, T1, footprint 5): two lighter piers on pilings,
-- an open lattice tower crane on the left pier with a long jib over the
-- basin, a shed and fuel tanks at the back, orange lights.
-- Model space, forward = -Z (docs/contracts/rig.md).

local parts = {
	{ name = "base", shape = "box", size = { 38, 0.6, 7 }, at = { 0, 0.3, 15.5 }, color = "dark" },
	{ name = "pierL", parent = "base", shape = "box", size = { 4.5, 1.2, 33 }, at = { -16.5, 1.4, -2 }, color = "hull" },
	{ name = "pierR", parent = "base", shape = "box", size = { 4.5, 1.2, 33 }, at = { 16.5, 1.4, -2 }, color = "hull" },
	{ name = "pierTeamL", parent = "base", shape = "box", size = { 3.4, 0.08, 8 }, at = { -16.5, 2.04, -10 }, color = "team" },
	{ name = "pierTeamR", parent = "base", shape = "box", size = { 3.4, 0.08, 8 }, at = { 16.5, 2.04, -10 }, color = "team" },
	{ name = "shed", parent = "base", shape = "box", size = { 14, 5, 6 }, at = { -6, 3.1, 15.5 }, color = "hull" },
	{ name = "tankA", parent = "base", shape = "cylinder", axis = "y", size = { 3, 4, 3 }, at = { 6, 2.6, 15.5 }, color = "metal" },
	{ name = "tankB", parent = "base", shape = "cylinder", axis = "y", size = { 3, 4, 3 }, at = { 10, 2.6, 15.5 }, color = "metal" },
	{ name = "towerA", parent = "base", shape = "box", size = { 0.5, 12, 0.5 }, at = { -17.5, 8, 3 }, color = "dark" },
	{ name = "towerB", parent = "base", shape = "box", size = { 0.5, 12, 0.5 }, at = { -15.5, 8, 3 }, color = "dark" },
	{ name = "towerC", parent = "base", shape = "box", size = { 0.5, 12, 0.5 }, at = { -17.5, 8, 5 }, color = "dark" },
	{ name = "towerD", parent = "base", shape = "box", size = { 0.5, 12, 0.5 }, at = { -15.5, 8, 5 }, color = "dark" },
	{ name = "jib", parent = "base", shape = "box", size = { 26, 0.8, 1 }, at = { -4, 14.2, 4 }, color = "metal" },
	{ name = "jibTeam", parent = "base", shape = "box", size = { 12, 0.08, 0.8 }, at = { 0, 14.64, 4 }, color = "team" },
	{ name = "lightA", parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { 9, 14.8, 4 }, color = "glass" },
	{ name = "lightL", parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { -16.5, 2.3, -18 }, color = "glass" },
	{ name = "lightR", parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { 16.5, 2.3, -18 }, color = "glass" },
}
for i = 0, 4 do
	local z = -16 + i * 7.5
	for _, x in { -16.5, 16.5 } do
		table.insert(parts, { name = `pile{i}{x > 0 and "R" or "L"}`, parent = "base", shape = "cylinder", axis = "y", size = { 0.8, 1.4, 0.8 }, at = { x, 0.4, z }, color = "dark" })
	end
end

return {
	id = "chs_shipyard",
	parts = parts,
	-- nanoframe anchors (M-25, rig.md 8)
	attachments = {
		{ name = "buildpad", parent = "base", at = { 0, 0, 1 } },
		{ name = "nano1", parent = "base", at = { 4, 13.1, 4 } },
	},
}
