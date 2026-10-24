--!strict
-- Aegis (Order radar SAM site, T2, footprint 3): an armored base, a turntable
-- on a pedestal carrying six upright canisters in an open frame that launch
-- straight up (the user: radar SAMs launch vertically), and a flat
-- engagement radar panel on its own block. The def turns `launcher` on the
-- pedestal's axis (M-3). Matches the mesh's layout (assets/models/ord_aegis).
-- Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 20, 1.4, 20 }, at = { 0, 0.7, 0 }, color = "hull" },
	{ name = "wallF", parent = "base", shape = "wedge", size = { 20, 1.4, 2 }, at = { 0, 0.7, -11 }, color = "hull" },
	{ name = "pedestal", parent = "base", shape = "cylinder", axis = "y", size = { 4.4, 2, 4.4 }, at = { -3, 2.4, 1 }, color = "dark" },
	{ name = "radarBlock", parent = "base", shape = "box", size = { 4.4, 3.4, 4.4 }, at = { 6, 3.1, 5 }, color = "hull" },
	{ name = "radarPanel", parent = "base", shape = "box", size = { 5.4, 4, 0.5 }, at = { 6, 6.8, 4.6 }, rot = { 15, 0, 0 }, color = "dark", anim = { motion = "turn", axis = { 0, 1, 0 } } },
	{ name = "radarFace", parent = "base", shape = "box", size = { 4.8, 3.4, 0.1 }, at = { 6, 6.85, 4.27 }, rot = { 15, 0, 0 }, color = "glass" },
	{ name = "teamA", parent = "base", shape = "box", size = { 4, 0.1, 4 }, at = { 6, 1.45, -6 }, color = "team" },

	{ name = "launcher", parent = "base", shape = "cylinder", axis = "y", size = { 5, 0.6, 5 }, at = { -3, 3.7, 1 }, pivot = { -3, 3.4, 1 }, color = "metal" },
	{ name = "cradle", parent = "launcher", shape = "box", size = { 6.4, 0.3, 4.4 }, at = { -3, 3.75, 1 }, color = "metal" },
	{ name = "cheekL", parent = "launcher", shape = "box", size = { 0.6, 3.8, 5.2 }, at = { -6.25, 5.9, 1 }, color = "hull" },
	{ name = "cheekR", parent = "launcher", shape = "box", size = { 0.6, 3.8, 5.2 }, at = { 0.25, 5.9, 1 }, color = "hull" },
	{ name = "cheekTeam", parent = "launcher", shape = "box", size = { 0.05, 1.2, 2.6 }, at = { -6.57, 6.8, 0.6 }, color = "team" },
}
for i, dx in { -1.95, 0, 1.95 } do
	for j, dz in { -1, 1 } do
		table.insert(parts, { name = `can{i}{j}`, parent = "launcher", shape = "cylinder", axis = "y", size = { 1.8, 7, 1.8 }, at = { -3 + dx, 7.4, 1 + dz }, color = "hull" })
		table.insert(parts, { name = `canTeam{i}{j}`, parent = "launcher", shape = "cylinder", axis = "y", size = { 1.86, 0.5, 1.86 }, at = { -3 + dx, 9.9, 1 + dz }, color = "team" })
	end
end

return {
	id = "ord_aegis",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { -4.95, 10.95, 0 } },
	},
}
