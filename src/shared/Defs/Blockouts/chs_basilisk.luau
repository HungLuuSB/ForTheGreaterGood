--!strict
-- Basilisk (Chaos point defence, T2, footprint 3, S-149): a patched pad, a
-- wide low welded rack of 24 short upright tubes behind a slab blast shield
-- (`launcher`, static), reactive blocks along it, ammo crates, and a lattice
-- post at the back right with a dish. Matches the mesh's layout
-- (assets/models/chs_basilisk). Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "cylinder", axis = "y", size = { 22, 0.8, 22 }, at = { 0, 0.4, 0 }, color = "dark" },
	{ name = "teamA", parent = "base", shape = "box", size = { 2.6, 0.1, 6 }, at = { -8.4, 0.85, -2 }, color = "team" },
	{ name = "teamB", parent = "base", shape = "box", size = { 3.4, 0.1, 3.4 }, at = { 5, 0.85, -2 }, color = "team" },
	{ name = "blocksF", parent = "base", shape = "box", size = { 8.6, 1, 0.6 }, at = { -2, 1.3, -3.4 }, color = "hull" },
	{ name = "blocksB", parent = "base", shape = "box", size = { 8.6, 1, 0.6 }, at = { -2, 1.3, 3.4 }, color = "hull" },
	{ name = "crates", parent = "base", shape = "box", size = { 2.6, 1, 2.6 }, at = { 4.7, 1.3, 5.2 }, color = "metal" },
	{ name = "post", parent = "base", shape = "box", size = { 1.6, 7, 1.6 }, at = { 7.4, 4.3, 6.6 }, color = "dark" },
	{ name = "dish", parent = "base", shape = "cylinder", axis = "z", size = { 3.8, 3.8, 0.5 }, at = { 7.4, 9.4, 6 }, rot = { -30, 0, 0 }, color = "hull", anim = { motion = "turn", axis = { 0, 1, 0 } } },

	{ name = "launcher", parent = "base", shape = "box", size = { 7.6, 0.5, 5.6 }, at = { -2, 1.2, 0 }, pivot = { -2, 1.6, 0 }, color = "metal" },
	{ name = "shield", parent = "launcher", shape = "box", size = { 7.8, 3.2, 0.4 }, at = { -2, 3.2, 3.3 }, color = "hull" },
	{ name = "shieldTeam", parent = "launcher", shape = "box", size = { 3, 1.2, 0.1 }, at = { -2, 3.5, 3.55 }, color = "team" },
}
for i = 0, 5 do
	for j = 0, 3 do
		table.insert(parts, { name = `tube{i}{j}`, parent = "launcher", shape = "cylinder", axis = "y", size = { 0.88, 3, 0.88 }, at = { -2 + (i - 2.5) * 1.15, 3.1, (j - 1.5) * 1.2 }, color = "metal" })
	end
end

return {
	id = "chs_basilisk",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { -4.875, 4.65, -1.8 } },
	},
}
