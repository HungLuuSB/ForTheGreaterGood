--!strict
-- Judgement (Order MLRS, T2, footprint 1): a heavy tracked hull with deep
-- skirts and a front cab; on a low turntable (`turret`) the `launcher`: one
-- closed armored pod, its front face a grid of tube mouths, raised 25° on
-- its rear hinge, team plate on the lid. Order reads heavy (M-14). The
-- weapon turns `launcher`; turning `turret` and pitching `launcher` works
-- too (M-3). Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 5.6, 1.4, 7.4 }, at = { 0, 1.5, 0.2 }, color = "hull" },
	{ name = "trackL", parent = "base", shape = "box", size = { 1.1, 1.3, 7.8 }, at = { -2.8, 0.65, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
	{ name = "trackR", parent = "base", shape = "box", size = { 1.1, 1.3, 7.8 }, at = { 2.8, 0.65, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
	{ name = "skirtL", parent = "base", shape = "box", size = { 0.4, 1.2, 7.4 }, at = { -3.5, 1.15, 0 }, color = "hull" },
	{ name = "skirtR", parent = "base", shape = "box", size = { 0.4, 1.2, 7.4 }, at = { 3.5, 1.15, 0 }, color = "hull" },
	{ name = "cab", parent = "base", shape = "box", size = { 5.0, 1.1, 1.8 }, at = { 0, 2.75, -2.6 }, color = "hull" },
	{ name = "cabGlass", parent = "base", shape = "box", size = { 3.6, 0.25, 0.08 }, at = { 0, 2.95, -3.54 }, color = "glass" },
	{ name = "cabTeam", parent = "base", shape = "box", size = { 3.6, 0.08, 1.2 }, at = { 0, 3.34, -2.6 }, color = "team" },

	{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 3.6, 0.5, 3.6 }, at = { 0, 2.45, 1.4 }, color = "dark" },
	{ name = "launcher", parent = "turret", shape = "box", size = { 4.2, 1.8, 4.6 }, at = { 0, 3.95, 1.0 }, rot = { 25, 0, 0 }, pivot = { 0, 2.9, 3.2 }, color = "hull" },
	{ name = "lidTeam", parent = "launcher", shape = "box", size = { 3.2, 0.08, 3.4 }, at = { 0, 4.85, 1.45 }, rot = { 25, 0, 0 }, color = "team" },
}
-- tube mouths on the pod's front face (2 rows of 4)
for row = 0, 1 do
	for col = 0, 3 do
		table.insert(parts, {
			name = `tube{row}{col}`, parent = "launcher", shape = "box", size = { 0.6, 0.5, 0.1 },
			at = { -1.5 + col, 3.6 + row * 0.75, -1.2 - row * 0.32 }, rot = { 25, 0, 0 }, color = "dark",
		})
	end
end

return {
	id = "ord_judgement",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { 0, 4.0, -1.4 } },
	},
}
