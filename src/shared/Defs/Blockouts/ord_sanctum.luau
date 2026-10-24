--!strict
-- Sanctum (Order point defence, T2, footprint 3, S-149): a chamfered slab, an
-- armored bunker with a flat vertical-launch module of 4 x 4 cell hatches on
-- its roof (`launcher`, static), and a short radar tower at the back right
-- with a radome. Matches the mesh's layout (assets/models/ord_sanctum).
-- Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 22, 0.6, 22 }, at = { 0, 0.3, 0 }, color = "hull" },
	{ name = "bunker", parent = "base", shape = "box", size = { 11, 3.4, 11 }, at = { -2, 2.3, 0 }, color = "hull" },
	{ name = "bunkerTeamL", parent = "base", shape = "box", size = { 0.1, 1.2, 6 }, at = { -7.6, 3.2, 0 }, color = "team" },
	{ name = "bunkerTeamR", parent = "base", shape = "box", size = { 0.1, 1.2, 6 }, at = { 3.6, 3.2, 0 }, color = "team" },
	{ name = "door", parent = "base", shape = "box", size = { 3, 1.8, 0.1 }, at = { -2, 1.7, 5.55 }, color = "dark" },
	{ name = "tower", parent = "base", shape = "box", size = { 3, 4.8, 3 }, at = { 7, 3, 7 }, color = "hull" },
	{ name = "towerTeam", parent = "base", shape = "box", size = { 0.1, 1.8, 1.6 }, at = { 5.45, 3.6, 7 }, color = "team" },
	{ name = "radome", parent = "base", shape = "ball", size = { 2.9, 2.9, 2.9 }, at = { 7, 7, 7 }, color = "metal" },
	{ name = "cabinet", parent = "base", shape = "box", size = { 3.6, 1.6, 2.8 }, at = { 7.4, 1.4, -6 }, color = "metal" },
	{ name = "teamA", parent = "base", shape = "box", size = { 4, 0.1, 4 }, at = { -8, 0.65, -8 }, color = "team" },

	{ name = "launcher", parent = "base", shape = "box", size = { 7.2, 0.5, 7.2 }, at = { -2, 4.25, 0 }, pivot = { -2, 4, 0 }, color = "metal" },
	{ name = "launcherTeam", parent = "launcher", shape = "box", size = { 6, 0.9, 0.1 }, at = { -2, 3.9, -3.65 }, color = "team" },
}
for i = 0, 3 do
	for j = 0, 3 do
		table.insert(parts, { name = `hatch{i}{j}`, parent = "launcher", shape = "box", size = { 1.2, 0.16, 1.2 }, at = { -2 + (i - 1.5) * 1.55, 4.6, (j - 1.5) * 1.55 }, color = "hull" })
	end
end

return {
	id = "ord_sanctum",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { -4.325, 4.7, -2.325 } },
	},
}
