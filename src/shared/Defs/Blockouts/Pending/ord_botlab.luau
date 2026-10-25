--!strict
-- Bot Lab (Order bot factory, T1, footprint 4; S-181): an armored assembly
-- hall at the back with buttresses, team roof panels and a control cab, and
-- in front a tall portal gantry over a lit assembly pad: the bot stands up
-- under the gantry's three emitters and walks out at -Z. Order reads clean
-- and heavy (M-14). Model space, forward = -Z (docs/contracts/rig.md).

local PZ = -6.5 -- the pad's centre
local GY = 13.6 -- the gantry beam's height

local parts = {
	{ name = "base", shape = "box", size = { 30, 0.6, 30 }, at = { 0, 0.3, 0 }, color = "dark" },
	{ name = "pad", parent = "base", shape = "box", size = { 13, 0.2, 12 }, at = { 0, 0.7, PZ }, color = "metal" },
	{ name = "padRing", parent = "base", shape = "cylinder", axis = "y", size = { 8, 0.1, 8 }, at = { 0, 0.85, PZ }, color = "glass" },
	{ name = "padHazard", parent = "base", shape = "box", size = { 13, 0.06, 0.8 }, at = { 0, 0.83, PZ - 6.4 }, color = "hazard" },

	-- the hall
	{ name = "hall", parent = "base", shape = "box", size = { 26, 9, 14 }, at = { 0, 5.1, 7.5 }, color = "hull" },
	{ name = "hallFront", parent = "base", shape = "wedge", size = { 26, 9, 1.6 }, at = { 0, 5.1, -0.3 }, color = "hull" },
	{ name = "door", parent = "base", shape = "box", size = { 10, 6.5, 0.3 }, at = { 0, 3.85, -0.6 }, rot = { 0, 0, 0 }, color = "dark" },
	{ name = "doorLight", parent = "base", shape = "box", size = { 10, 0.3, 0.12 }, at = { 0, 7.3, -0.75 }, color = "glass" },
	{ name = "roof", parent = "base", shape = "box", size = { 26.4, 0.8, 14.4 }, at = { 0, 10, 7.5 }, color = "dark" },
	{ name = "roofTeamL", parent = "base", shape = "box", size = { 9, 0.12, 9 }, at = { -6.5, 10.46, 8 }, color = "team" },
	{ name = "roofTeamR", parent = "base", shape = "box", size = { 9, 0.12, 9 }, at = { 6.5, 10.46, 8 }, color = "team" },
	{ name = "cab", parent = "base", shape = "box", size = { 5, 3.6, 4.4 }, at = { 9.5, 12.2, 11 }, color = "hull" },
	{ name = "cabGlass", parent = "base", shape = "box", size = { 4.4, 1, 0.1 }, at = { 9.5, 12.8, 8.75 }, color = "glass" },
	{ name = "mast", parent = "base", shape = "box", size = { 0.4, 4, 0.4 }, at = { 11.2, 16, 12 }, color = "dark" },
	{ name = "buttressL", parent = "base", shape = "wedge", size = { 6, 6, 2.4 }, at = { -14.2, 3.6, 7.5 }, rot = { 0, 90, 0 }, color = "hull" },
	{ name = "buttressR", parent = "base", shape = "wedge", size = { 6, 6, 2.4 }, at = { 14.2, 3.6, 7.5 }, rot = { 0, -90, 0 }, color = "hull" },

	-- the portal gantry over the pad
	{ name = "pillarL", parent = "base", shape = "box", size = { 2, GY - 0.6, 2.2 }, at = { -8.5, (GY - 0.6) / 2 + 0.6, PZ }, color = "hull" },
	{ name = "pillarR", parent = "base", shape = "box", size = { 2, GY - 0.6, 2.2 }, at = { 8.5, (GY - 0.6) / 2 + 0.6, PZ }, color = "hull" },
	{ name = "pillarTeamL", parent = "base", shape = "box", size = { 0.08, 4, 1.4 }, at = { -9.54, 6, PZ }, color = "team" },
	{ name = "pillarTeamR", parent = "base", shape = "box", size = { 0.08, 4, 1.4 }, at = { 9.54, 6, PZ }, color = "team" },
	{ name = "beam", parent = "base", shape = "box", size = { 19, 2, 2.6 }, at = { 0, GY + 1, PZ }, color = "hull" },
	{ name = "beamLight", parent = "base", shape = "box", size = { 15, 0.2, 0.1 }, at = { 0, GY + 1, PZ - 1.35 }, color = "glass" },
	{ name = "beamTie", parent = "base", shape = "box", size = { 1.6, 1.4, 6.5 }, at = { 0, GY + 0.8, PZ + 4.3 }, color = "dark" },
	{ name = "emitterL", parent = "base", shape = "box", size = { 1, 0.8, 1 }, at = { -4.5, GY - 0.4, PZ }, color = "metal" },
	{ name = "emitterC", parent = "base", shape = "box", size = { 1, 0.8, 1 }, at = { 0, GY - 0.4, PZ }, color = "metal" },
	{ name = "emitterR", parent = "base", shape = "box", size = { 1, 0.8, 1 }, at = { 4.5, GY - 0.4, PZ }, color = "metal" },
	{ name = "beaconL", parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { -14, 1, -14 }, color = "glass" },
	{ name = "beaconR", parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { 14, 1, -14 }, color = "glass" },
}

return {
	id = "ord_botlab",
	parts = parts,
	-- nanoframe anchors (M-25, rig.md 8)
	attachments = {
		{ name = "buildpad", parent = "base", at = { 0, 0.8, PZ } },
		{ name = "nano1", parent = "base", at = { -4.5, GY - 0.9, PZ } },
		{ name = "nano2", parent = "base", at = { 4.5, GY - 0.9, PZ } },
		{ name = "nano3", parent = "base", at = { 0, GY - 0.9, PZ } },
	},
}
