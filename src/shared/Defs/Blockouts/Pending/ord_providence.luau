--!strict
-- Providence (Order anti-nuke, proposed: T2 structure, footprint 3, the size
-- scale's T2 defense class; the user's request 2026-10-23, sim to define):
-- an armored launch bunker with sloped walls, a silo under a heavy armored
-- `hatch` (hinged at its back edge; pose `open`), a row of readiness lights
-- round the silo (power / weapon glow on the mesh: a loaded interceptor reads
-- at a glance), and a tracking radar (client-only `radar`, turns) on a short
-- tower at the back. `muzzle` at the silo mouth, launching straight up.
-- Model space, forward = -Z.

return {
	id = "ord_providence",
	visualPieces = { "radar" },
	parts = {
		{ name = "base", shape = "box", size = { 19, 3, 19 }, at = { 0, 1.5, 0 }, color = "hull" },
		{ name = "wallF", parent = "base", shape = "wedge", size = { 19, 3, 1.6 }, at = { 0, 1.5, -10.3 }, color = "hull" },
		{ name = "wallB", parent = "base", shape = "wedge", size = { 19, 3, 1.6 }, at = { 0, 1.5, 10.3 }, rot = { 0, 180, 0 }, color = "hull" },
		{ name = "wallL", parent = "base", shape = "wedge", size = { 19, 3, 1.6 }, at = { -10.3, 1.5, 0 }, rot = { 0, 90, 0 }, color = "hull" },
		{ name = "wallR", parent = "base", shape = "wedge", size = { 19, 3, 1.6 }, at = { 10.3, 1.5, 0 }, rot = { 0, -90, 0 }, color = "hull" },
		{ name = "teamL", parent = "base", shape = "box", size = { 3.5, 0.08, 9 }, at = { -7.2, 3.04, -1 }, color = "team" },
		{ name = "teamR", parent = "base", shape = "box", size = { 3.5, 0.08, 9 }, at = { 7.2, 3.04, -1 }, color = "team" },
		-- the silo: a raised collar, the dark pit, readiness lights along its front
		{ name = "collarF", parent = "base", shape = "box", size = { 9, 0.9, 1.2 }, at = { 0, 3.45, -5.1 }, color = "hull" },
		{ name = "collarB", parent = "base", shape = "box", size = { 9, 0.9, 1.2 }, at = { 0, 3.45, 3.1 }, color = "hull" },
		{ name = "collarL", parent = "base", shape = "box", size = { 1.2, 0.9, 7 }, at = { -3.9, 3.45, -1 }, color = "hull" },
		{ name = "collarR", parent = "base", shape = "box", size = { 1.2, 0.9, 7 }, at = { 3.9, 3.45, -1 }, color = "hull" },
		{ name = "pit", parent = "base", shape = "box", size = { 6.6, 0.1, 7 }, at = { 0, 3.02, -1 }, color = "dark" },
		{ name = "ready1", parent = "base", shape = "box", size = { 1.6, 0.3, 0.12 }, at = { -2.4, 3.6, -5.75 }, color = "glass" },
		{ name = "ready2", parent = "base", shape = "box", size = { 1.6, 0.3, 0.12 }, at = { 0, 3.6, -5.75 }, color = "glass" },
		{ name = "ready3", parent = "base", shape = "box", size = { 1.6, 0.3, 0.12 }, at = { 2.4, 3.6, -5.75 }, color = "glass" },
		-- the heavy hatch: hinged at its back edge on the rear collar
		{ name = "hatch", parent = "base", shape = "box", size = { 7, 0.9, 7.4 }, at = { 0, 4.35, -1 }, pivot = { 0, 4.35, 2.7 }, color = "hull", anim = { motion = "open", axis = { 1, 0, 0 }, range = 110 } },
		{ name = "hatchTeam", parent = "hatch", shape = "box", size = { 3.6, 0.08, 3.6 }, at = { 0, 4.84, -1.2 }, color = "team" },
		{ name = "hatchRib", parent = "hatch", shape = "box", size = { 7.2, 0.3, 0.6 }, at = { 0, 4.95, -3.8 }, color = "dark" },
		-- tracking radar on a short tower at the back right
		{ name = "tower", parent = "base", shape = "box", size = { 2.4, 4, 2.4 }, at = { 6.6, 5, 6.6 }, color = "hull" },
		{ name = "radar", parent = "base", shape = "box", size = { 4, 2.6, 0.35 }, at = { 6.6, 8.3, 6.6 }, rot = { 20, 0, 0 }, pivot = { 6.6, 7.0, 6.6 }, color = "dark", anim = { motion = "turn", axis = { 0, 1, 0 } } },
		{ name = "radarFace", parent = "radar", shape = "box", size = { 3.6, 2.2, 0.06 }, at = { 6.6, 8.35, 6.4 }, rot = { 20, 0, 0 }, color = "glass" },
	},
	attachments = {
		{ name = "muzzle", parent = "base", at = { 0, 3.2, -1 } },
	},
}
