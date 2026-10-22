--!strict
-- Cerberus (Chaos anti-nuke, proposed: T2 structure, footprint 3; the user's
-- request 2026-10-23, sim to define): a reinforced pad with blast deflectors
-- and a `launcher`, a rail frame with two interceptor tubes lying back on
-- their rear hinge (pose `raised`: swung up to vertical), readiness lights
-- at the tube mouths (power / weapon glow on the mesh), and a lattice radar
-- mast with a turning array (client-only `radar`). `muzzle` between the tube
-- mouths. Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 19, 1.2, 19 }, at = { 0, 0.6, 0 }, color = "dark" },
	{ name = "padTeam", parent = "base", shape = "box", size = { 4, 0.08, 3 }, at = { -6.5, 1.24, -6.5 }, color = "team" },
	{ name = "padTeam2", parent = "base", shape = "box", size = { 4, 0.08, 3 }, at = { 6.5, 1.24, -6.5 }, color = "team" },
	{ name = "deflector", parent = "base", shape = "wedge", size = { 9, 2.6, 2.2 }, at = { 0, 2.5, 7.4 }, rot = { 0, 180, 0 }, color = "metal" },
	{ name = "blockL", parent = "base", shape = "box", size = { 1.6, 2, 9 }, at = { -4.6, 2.2, 1 }, color = "hull" },
	{ name = "blockR", parent = "base", shape = "box", size = { 1.6, 2, 9 }, at = { 4.6, 2.2, 1 }, color = "hull" },
	-- the launcher: a rail frame with two tubes, hinged at its rear end
	{ name = "launcher", parent = "base", shape = "box", size = { 5.4, 0.6, 9.4 }, at = { 0, 1.9, 0.6 }, pivot = { 0, 1.6, 5.2 }, color = "metal" },
	{ name = "tubeL", parent = "launcher", shape = "cylinder", axis = "z", size = { 1.6, 1.6, 8.6 }, at = { -1.35, 3.0, 0.6 }, color = "hull" },
	{ name = "tubeR", parent = "launcher", shape = "cylinder", axis = "z", size = { 1.6, 1.6, 8.6 }, at = { 1.35, 3.0, 0.6 }, color = "hull" },
	{ name = "readyL", parent = "launcher", shape = "cylinder", axis = "z", size = { 1.2, 1.2, 0.12 }, at = { -1.35, 3.0, -3.75 }, color = "glass" },
	{ name = "readyR", parent = "launcher", shape = "cylinder", axis = "z", size = { 1.2, 1.2, 0.12 }, at = { 1.35, 3.0, -3.75 }, color = "glass" },
	{ name = "launcherTeam", parent = "launcher", shape = "box", size = { 1.0, 0.08, 4 }, at = { 0, 3.84, 1.2 }, color = "team" },
	-- lattice radar mast at the back left, the array on top, a beacon
	{ name = "mast", parent = "base", shape = "box", size = { 0.6, 11, 0.6 }, at = { -7, 6.7, 7 }, color = "dark" },
	{ name = "braceA", parent = "base", shape = "box", size = { 0.25, 10, 0.25 }, at = { -6.2, 6.2, 7 }, rot = { 0, 0, -6 }, color = "dark" },
	{ name = "braceB", parent = "base", shape = "box", size = { 0.25, 10, 0.25 }, at = { -7, 6.2, 6.2 }, rot = { 6, 0, 0 }, color = "dark" },
	{ name = "radar", parent = "base", shape = "box", size = { 4.2, 2.4, 0.3 }, at = { -7, 13.2, 7 }, rot = { 20, 0, 0 }, pivot = { -7, 12.2, 7 }, color = "metal", anim = { motion = "turn", axis = { 0, 1, 0 } } },
	{ name = "radarFace", parent = "radar", shape = "box", size = { 3.8, 2.0, 0.06 }, at = { -7, 13.25, 6.82 }, rot = { 20, 0, 0 }, color = "glass" },
	{ name = "beacon", parent = "base", shape = "ball", size = { 0.5, 0.5, 0.5 }, at = { -7, 12.4, 7 }, color = "glass" },
}

return {
	id = "chs_cerberus",
	visualPieces = { "radar" },
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { 0, 3.0, -3.9 } },
	},
}
