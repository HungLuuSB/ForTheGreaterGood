--!strict
-- Wyvern (Chaos radar SAM site, T2, footprint 3): a pad with a post carrying
-- an open frame of bare upright tubes that launch straight up (the user:
-- radar SAMs launch vertically; more tubes than the Aegis), and a lattice
-- mast with a flat radar panel. The def turns `launcher` on the post's axis
-- (M-3). Matches the mesh's layout (assets/models/chs_wyvern). Model space,
-- forward = -Z.

local parts = {
	{ name = "base", shape = "cylinder", axis = "y", size = { 20, 0.8, 20 }, at = { 0, 0.4, 0 }, color = "dark" },
	{ name = "post", parent = "base", shape = "cylinder", axis = "y", size = { 2.4, 3, 2.4 }, at = { -3, 2.3, 1 }, color = "hull" },
	{ name = "teamA", parent = "base", shape = "box", size = { 4, 0.1, 4 }, at = { 5, 0.85, -5 }, color = "team" },
	{ name = "mast", parent = "base", shape = "box", size = { 0.6, 8, 0.6 }, at = { 6, 4.8, 5 }, color = "dark" },
	{ name = "mastBrace", parent = "base", shape = "box", size = { 0.3, 7, 0.3 }, at = { 7, 4.3, 5 }, rot = { 0, 0, 10 }, color = "dark" },
	{ name = "radarPanel", parent = "base", shape = "box", size = { 5, 3.2, 0.4 }, at = { 6, 10.6, 5 }, rot = { 15, 0, 0 }, color = "hull", anim = { motion = "turn", axis = { 0, 1, 0 } } },
	{ name = "radarEye", parent = "base", shape = "box", size = { 1, 0.6, 0.2 }, at = { 6, 10.2, 4.5 }, color = "glass" },

	{ name = "launcher", parent = "base", shape = "box", size = { 2.4, 1.4, 2.4 }, at = { -3, 4.5, 1 }, pivot = { -3, 3.8, 1 }, color = "hull" },
	{ name = "frame", parent = "launcher", shape = "box", size = { 10, 0.4, 0.4 }, at = { -3, 5.0, 1.9 }, color = "dark" },
	{ name = "frameTop", parent = "launcher", shape = "box", size = { 10, 0.3, 0.3 }, at = { -3, 9.4, 1.9 }, color = "dark" },
	{ name = "launcherTeam", parent = "launcher", shape = "box", size = { 2, 2.4, 0.08 }, at = { -3, 7.4, 2.15 }, color = "team" },
	{ name = "sensor", parent = "launcher", shape = "box", size = { 1, 0.4, 0.1 }, at = { -3, 5.4, -0.25 }, color = "glass" },
}
for i, dx in { -4.4, -3.6, -2.8, 2.8, 3.6, 4.4 } do
	for j, dz in { -0.45, 0.45 } do
		table.insert(parts, { name = `tube{i}{j}`, parent = "launcher", shape = "cylinder", axis = "y", size = { 0.7, 6.2, 0.7 }, at = { -3 + dx, 7.7, 1 + dz }, color = "metal" })
	end
end

return {
	id = "chs_wyvern",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { -7.4, 10.9, 1.45 } },
	},
}
