--!strict
-- Chimera (Chaos mobile anti-nuke, proposed: T2 ground, footprint 1, from the
-- advanced vehicle plant; the user's request 2026-10-23, sim to define): a
-- lighter 6x6 truck about 1.3x a T1 truck (size scale) with an open cab, an
-- exposed launch rail carrying one slim interceptor (`launcher`, hinged at
-- its rear end; pose `raised`), a readiness light at the missile's nose
-- (power / weapon glow on the mesh), and a lattice radar mast at the back
-- with a turning array (client-only `radar`). `muzzle` at the rail's front.
-- Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 4.4, 1.2, 9.8 }, at = { 0, 1.7, 0 }, color = "dark" },
	{ name = "cab", parent = "base", shape = "box", size = { 4.0, 1.6, 2.2 }, at = { 0, 3.1, -3.7 }, color = "hull" },
	{ name = "cabSlit", parent = "base", shape = "box", size = { 3.0, 0.25, 0.1 }, at = { 0, 3.5, -4.82 }, color = "glass" },
	{ name = "cabTeam", parent = "base", shape = "box", size = { 2.8, 0.08, 1.4 }, at = { 0, 3.94, -3.7 }, color = "team" },
	{ name = "bedTeam", parent = "base", shape = "box", size = { 1.0, 0.08, 3.4 }, at = { -1.6, 2.34, 1.4 }, color = "team" },
	{ name = "rest", parent = "base", shape = "box", size = { 1.6, 0.8, 0.4 }, at = { 0, 2.7, -1.9 }, color = "metal" },
	-- the exposed rail and its interceptor, hinged at the rear
	{ name = "launcher", parent = "base", shape = "box", size = { 0.8, 0.4, 7.6 }, at = { 0, 3.0, 0.6 }, pivot = { 0, 2.7, 4.4 }, color = "metal" },
	{ name = "missile", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 7.0 }, at = { 0, 3.65, 0.6 }, color = "hull" },
	{ name = "ready", parent = "launcher", shape = "ball", size = { 0.7, 0.7, 0.9 }, at = { 0, 3.65, -2.95 }, color = "glass" },
	-- lattice radar mast at the back right, the array on top
	{ name = "mast", parent = "base", shape = "box", size = { 0.4, 5.6, 0.4 }, at = { 1.7, 5.1, 4.2 }, color = "dark" },
	{ name = "brace", parent = "base", shape = "box", size = { 0.18, 5.2, 0.18 }, at = { 1.7, 4.9, 3.6 }, rot = { 8, 0, 0 }, color = "dark" },
	{ name = "radar", parent = "base", shape = "box", size = { 2.4, 1.4, 0.2 }, at = { 1.7, 8.3, 4.2 }, rot = { 15, 0, 0 }, pivot = { 1.7, 7.8, 4.2 }, color = "metal", anim = { motion = "turn", axis = { 0, 1, 0 } } },
}
for i, z in { -3.6, 1.2, 3.6 } do
	table.insert(parts, { name = `wheelL{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.7, 1.5, 1.5 }, at = { -2.3, 0.75, z }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } })
	table.insert(parts, { name = `wheelR{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.7, 1.5, 1.5 }, at = { 2.3, 0.75, z }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } })
end

return {
	id = "chs_chimera",
	visualPieces = { "radar" },
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { 0, 3.65, -3.5 } },
	},
}
