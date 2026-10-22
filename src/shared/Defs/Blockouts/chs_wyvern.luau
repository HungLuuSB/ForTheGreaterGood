--!strict
-- Wyvern (Chaos radar SAM site, T2, footprint 3): a pad with a post carrying
-- a launcher of bare canister tubes on an open frame (more tubes than the
-- Aegis), and a lattice mast with a flat radar panel. The def turns
-- `launcher` on the post's axis (M-3). Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "cylinder", axis = "y", size = { 20, 0.8, 20 }, at = { 0, 0.4, 0 }, color = "dark" },
	{ name = "post", parent = "base", shape = "cylinder", axis = "y", size = { 2.4, 3, 2.4 }, at = { -3, 2.3, 1 }, color = "hull" },
	{ name = "teamA", parent = "base", shape = "box", size = { 4, 0.1, 4 }, at = { 5, 0.85, -5 }, color = "team" },
	{ name = "mast", parent = "base", shape = "box", size = { 0.6, 8, 0.6 }, at = { 6, 4.8, 5 }, color = "dark" },
	{ name = "mastBrace", parent = "base", shape = "box", size = { 0.3, 7, 0.3 }, at = { 7, 4.3, 5 }, rot = { 0, 0, 10 }, color = "dark" },
	{ name = "radarPanel", parent = "base", shape = "box", size = { 5, 3.2, 0.4 }, at = { 6, 9.8, 5 }, rot = { 15, 0, 0 }, color = "hull", anim = { motion = "turn", axis = { 0, 1, 0 } } },
	{ name = "radarEye", parent = "base", shape = "box", size = { 1, 0.6, 0.2 }, at = { 6, 9.4, 4.5 }, color = "glass" },

	{ name = "launcher", parent = "base", shape = "box", size = { 2.4, 2, 3 }, at = { -3, 4.8, 1 }, pivot = { -3, 3.8, 1 }, color = "hull" },
	{ name = "launcherTeam", parent = "launcher", shape = "box", size = { 2, 0.08, 2.4 }, at = { -3, 5.84, 1 }, color = "team" },
	{ name = "frame", parent = "launcher", shape = "box", size = { 9, 0.3, 0.3 }, at = { -3, 4.6, 1.8 }, color = "dark" },
	{ name = "sensor", parent = "launcher", shape = "box", size = { 1, 0.4, 0.1 }, at = { -3, 5.2, -0.55 }, color = "glass" },
}
for i, dx in { -4, -3.2, -2.4, 2.4, 3.2, 4 } do
	for j, y in { 4.2, 5.0 } do
		table.insert(parts, { name = `tube{i}{j}`, parent = "launcher", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 4.4 }, at = { -3 + dx, y, 0.6 }, color = "metal" })
	end
end

return {
	id = "chs_wyvern",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { -7, 5.0, -1.65 } },
	},
}
