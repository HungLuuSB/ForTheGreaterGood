--!strict
-- Construction Turret (Order nano turret, T1, footprint 2; S-209, BAR
-- armnanotc): a stepped pad, four armored pillars with team panels round a
-- core, and on top the `turret` (yaws to its work) with the `nano` emitter
-- (the def's piece): a raised barrel with a big glowing lens that reads
-- from 150 studs; `nano1` at the lens (rig.md 8). Order reads clean and
-- heavy (M-14). Model space, forward = -Z.

local DECK = 6.0 -- top of the core, where the turret turns

local parts: { any } = {
	{ name = "base", shape = "box", size = { 15.6, 0.6, 15.6 }, at = { 0, 0.3, 0 }, color = "dark" },
	{ name = "core", parent = "base", shape = "box", size = { 5.2, DECK - 0.6, 5.2 }, at = { 0, 0.6 + (DECK - 0.6) / 2, 0 }, color = "metal" },
}
for i, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
	local x, z = c[1] * 2.7, c[2] * 2.7
	table.insert(parts, { name = `pillar{i}`, parent = "base", shape = "box", size = { 3.4, 4.6, 3.4 }, at = { x, 2.9, z }, color = "hull" })
	table.insert(parts, { name = `team{i}`, parent = "base", shape = "box", size = { 0.08, 2.6, 2.0 }, at = { x + c[1] * 1.74, 2.7, z }, color = "team" })
end
for _, p in {
	{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 4.2, 0.8, 4.2 }, at = { 0, DECK + 0.4, 0 }, pivot = { 0, DECK, 0 }, color = "metal" },
	{ name = "shoulder", parent = "turret", shape = "box", size = { 3.4, 2.6, 3.6 }, at = { 0, 8.1, 0.4 }, color = "hull" },
	{ name = "roofTeam", parent = "turret", shape = "box", size = { 2.4, 0.08, 2.4 }, at = { 0, 9.44, 0.9 }, color = "team" },
	{ name = "nano", parent = "turret", shape = "cylinder", axis = "z", size = { 1.7, 1.7, 4.4 }, at = { 0, 9.1, -1.5 }, rot = { 22, 0, 0 }, pivot = { 0, 8.3, 0.5 }, color = "metal" },
	{ name = "head", parent = "nano", shape = "cylinder", axis = "z", size = { 2.7, 2.7, 1.1 }, at = { 0, 9.9, -3.5 }, rot = { 22, 0, 0 }, color = "dark" },
	{ name = "lens", parent = "nano", shape = "ball", size = { 2.1, 2.1, 2.1 }, at = { 0, 10.3, -4.4 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_nano",
	parts = parts,
	-- nanoframe anchor (M-25, rig.md 8)
	attachments = {
		{ name = "nano1", parent = "nano", at = { 0, 10.4, -4.69 } },
	},
}
