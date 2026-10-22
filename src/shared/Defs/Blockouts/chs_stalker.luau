--!strict
-- Stalker (Chaos mobile fire-control radar, T2, footprint 1): a light 6 × 6
-- truck; on a lattice mast at the back the `dish`: a flat radar panel
-- (smaller than Order's Arbiter: cheaper, shorter-ranged), an orange sensor
-- strip, a generator with a stack. Team plate on the cab roof. Chaos reads
-- light (M-14). Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 4.2, 0.9, 7.2 }, at = { 0, 1.75, 0.1 }, color = "hull" },
	{ name = "cab", parent = "base", shape = "box", size = { 3.8, 1.1, 1.6 }, at = { 0, 2.75, -2.7 }, color = "hull" },
	{ name = "cabSlit", parent = "base", shape = "box", size = { 3.0, 0.2, 0.08 }, at = { 0, 2.95, -3.54 }, color = "glass" },
	{ name = "cabTeam", parent = "base", shape = "box", size = { 2.8, 0.08, 1.0 }, at = { 0, 3.34, -2.7 }, color = "team" },
	{ name = "generator", parent = "base", shape = "box", size = { 1.6, 1.0, 1.8 }, at = { 1.1, 2.7, -0.6 }, color = "metal" },
	{ name = "stack", parent = "base", shape = "cylinder", axis = "y", size = { 0.4, 1.4, 0.4 }, at = { 1.6, 3.6, -0.1 }, color = "metal" },
	{ name = "mastBase", parent = "base", shape = "box", size = { 1.6, 0.3, 1.6 }, at = { -0.4, 2.35, 2.2 }, color = "dark" },
}
for i, p in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
	table.insert(parts, { name = `leg{i}`, parent = "base", shape = "box", size = { 0.15, 3.2, 0.15 }, at = { -0.4 + p[1] * 0.5, 4.0, 2.2 + p[2] * 0.5 }, rot = { p[2] * -4, 0, p[1] * 4 }, color = "dark" })
end
table.insert(parts, { name = "dish", parent = "base", shape = "box", size = { 2.8, 1.8, 0.25 }, at = { -0.4, 6.3, 2.2 }, rot = { -15, 0, 0 }, pivot = { -0.4, 5.6, 2.2 }, color = "dark", anim = { motion = "turn", axis = { 0, 1, 0 } } })
table.insert(parts, { name = "dishGlow", parent = "dish", shape = "box", size = { 2.2, 0.25, 0.06 }, at = { -0.4, 6.3, 2.05 }, rot = { -15, 0, 0 }, color = "glass" })
for i, z in { -2.5, 0.6, 2.5 } do
	table.insert(parts, { name = `wheelL{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.6, 1.6, 1.6 }, at = { -2.1, 0.8, z }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } })
	table.insert(parts, { name = `wheelR{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.6, 1.6, 1.6 }, at = { 2.1, 0.8, z }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } })
end

return { id = "chs_stalker", parts = parts }
