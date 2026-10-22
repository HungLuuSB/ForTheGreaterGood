--!strict
-- Scrapper (Chaos ground worker): heavy tracked salvage tractor with a plow,
-- an offset slit cab, an open scrap hopper and a stack; a claw arm (nano) on
-- a turntable on the right, ending in an orange glow. Model space,
-- forward = -Z (docs/contracts/rig.md).

-- The arm is 3.2 long and tilted up 45° at the front: its front end is at
-- z = -0.83 - 1.6 cos 45° ≈ -1.96, y = 4.13 + 1.6 sin 45° ≈ 5.26.
return {
	id = "chs_scrapper",
	parts = {
		{ name = "base", shape = "box", size = { 5.4, 1.5, 6.8 }, at = { 0, 1.65, 0.3 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.3, 1.5, 7.6 }, at = { -2.9, 0.75, 0 }, color = "track" },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.3, 1.5, 7.6 }, at = { 2.9, 0.75, 0 }, color = "track" },
		{ name = "skirtR", parent = "base", shape = "box", size = { 0.3, 1.1, 6.4 }, at = { 3.7, 1.5, 0.1 }, color = "dark" },
		{ name = "plow", parent = "base", shape = "box", size = { 5.8, 1.2, 0.4 }, at = { 0, 1.0, -3.8 }, rot = { -25, 0, 0 }, color = "dark" },
		{ name = "cab", parent = "base", shape = "box", size = { 2.0, 1.2, 1.8 }, at = { -1.5, 3.0, -1.9 }, color = "hull" },
		{ name = "slit", parent = "base", shape = "box", size = { 1.6, 0.2, 0.1 }, at = { -1.5, 3.25, -2.82 }, color = "glass" },
		{ name = "hopper", parent = "base", shape = "box", size = { 2.6, 1.0, 2.4 }, at = { -1.0, 2.9, 1.8 }, color = "dark" },
		{ name = "scrap1", parent = "base", shape = "box", size = { 1.0, 0.5, 0.8 }, at = { -1.3, 3.5, 1.6 }, rot = { 0, 20, 15 }, color = "metal" },
		{ name = "scrap2", parent = "base", shape = "box", size = { 0.8, 0.4, 0.6 }, at = { -0.5, 3.45, 2.3 }, rot = { 10, 40, 0 }, color = "metal" },
		{ name = "stack", parent = "base", shape = "cylinder", axis = "y", size = { 0.5, 2.0, 0.5 }, at = { -2.3, 3.6, 3.2 }, color = "metal" },

		{ name = "nano", parent = "base", shape = "cylinder", axis = "y", size = { 1.6, 0.6, 1.6 }, at = { 1.5, 2.7, 0 }, color = "team" },
		{ name = "arm", parent = "nano", shape = "box", size = { 0.6, 0.6, 3.2 }, at = { 1.5, 4.13, -0.83 }, rot = { 45, 0, 0 }, color = "team" },
		{ name = "piston", parent = "nano", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 1.8 }, at = { 1.85, 3.6, -0.8 }, rot = { 25, 0, 0 }, color = "metal" },
		{ name = "claw", parent = "nano", shape = "box", size = { 1.0, 0.9, 0.6 }, at = { 1.5, 5.1, -2.3 }, color = "dark" },
		{ name = "glow", parent = "nano", shape = "ball", size = { 0.6, 0.6, 0.6 }, at = { 1.5, 4.75, -2.6 }, color = "glass" },
	},
	-- nanoframe anchors (M-25, rig.md 8)
	attachments = {
		{ name = "nano1", parent = "nano", at = { 1.5, 4.75, -2.6 } },
	},
}
