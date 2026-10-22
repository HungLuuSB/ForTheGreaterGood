--!strict
-- Hydra (Chaos MLRS, T2, footprint 1): a light tracked chassis with exposed
-- road wheels and a slat cage; on a turntable (`turret`) the `launcher`: an
-- open frame carrying a big cluster of bare tubes (3 × 4), raised 30° on its
-- rear hinge (large inaccurate salvos). Chaos reads light (M-14).
-- Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 4.6, 1.2, 7.2 }, at = { 0, 1.7, 0.2 }, color = "hull" },
	{ name = "trackL", parent = "base", shape = "box", size = { 0.9, 0.5, 7.6 }, at = { -2.75, 0.25, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
	{ name = "trackR", parent = "base", shape = "box", size = { 0.9, 0.5, 7.6 }, at = { 2.75, 0.25, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
	{ name = "cab", parent = "base", shape = "box", size = { 4.0, 1.0, 1.6 }, at = { 0, 2.8, -2.6 }, color = "hull" },
	{ name = "slit", parent = "base", shape = "box", size = { 3.0, 0.2, 0.08 }, at = { 0, 3.0, -3.44 }, color = "glass" },
	{ name = "cabTeam", parent = "base", shape = "box", size = { 2.8, 0.08, 1.0 }, at = { 0, 3.34, -2.6 }, color = "team" },
	{ name = "cageTop", parent = "base", shape = "box", size = { 4.8, 0.12, 0.12 }, at = { 0, 2.9, 3.9 }, color = "dark" },
	{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 3.0, 0.4, 3.0 }, at = { 0, 2.5, 1.2 }, color = "dark" },
	{ name = "launcher", parent = "turret", shape = "box", size = { 3.6, 0.3, 4.6 }, at = { 0, 3.3, 0.8 }, rot = { 30, 0, 0 }, pivot = { 0, 2.8, 3.0 }, color = "dark" },
	{ name = "frameL", parent = "launcher", shape = "box", size = { 0.2, 2.6, 4.6 }, at = { -1.85, 4.3, 0.2 }, rot = { 30, 0, 0 }, color = "dark" },
	{ name = "frameR", parent = "launcher", shape = "box", size = { 0.2, 2.6, 4.6 }, at = { 1.85, 4.3, 0.2 }, rot = { 30, 0, 0 }, color = "dark" },
}
for row = 0, 2 do
	for col = 0, 3 do
		table.insert(parts, {
			name = `tube{row}{col}`, parent = "launcher", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 4.4 },
			at = { -1.35 + col * 0.9, 3.75 + row * 0.75, 1.0 - row * 0.43 }, rot = { 30, 0, 0 }, color = "metal",
		})
	end
end
for i, z in { -2.3, -0.8, 0.8, 2.3 } do
	table.insert(parts, { name = `wheelL{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.6, 1.3, 1.3 }, at = { -2.75, 0.8, z }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } })
	table.insert(parts, { name = `wheelR{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.6, 1.3, 1.3 }, at = { 2.75, 0.8, z }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } })
end
for i, x in { -2, 0, 2 } do
	table.insert(parts, { name = `cage{i}`, parent = "base", shape = "box", size = { 0.1, 1.1, 0.1 }, at = { x, 2.35, 3.9 }, color = "dark" })
end

return {
	id = "chs_hydra",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { 0, 4.3, -1.8 } },
	},
}
