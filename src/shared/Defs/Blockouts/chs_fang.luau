--!strict
-- Fang (Chaos torpedo launcher, T1, footprint 1): a pontoon raft, a turntable
-- (`turret`) and two bare tubes on the `launcher` (the weapon turns it).
-- Model space, forward = -Z.

return {
	id = "chs_fang",
	parts = {
		{ name = "base", shape = "box", size = { 5.6, 0.4, 3 }, at = { 0, 0.8, 0 }, color = "dark" },
		{ name = "floatL", parent = "base", shape = "cylinder", axis = "z", size = { 1.3, 1.3, 5.6 }, at = { -2.1, 0.3, 0 }, color = "metal" },
		{ name = "floatR", parent = "base", shape = "cylinder", axis = "z", size = { 1.3, 1.3, 5.6 }, at = { 2.1, 0.3, 0 }, color = "metal" },
		{ name = "team", parent = "base", shape = "box", size = { 1.6, 0.08, 0.8 }, at = { 0, 1.04, 1 }, color = "team" },
		{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 1.8, 0.5, 1.8 }, at = { 0, 1.25, -0.3 }, color = "dark" },
		{ name = "sonar", parent = "base", shape = "box", size = { 0.6, 0.15, 0.06 }, at = { 1.6, 1.1, -1.5 }, color = "glass", anim = { motion = "lower", axis = { 0, -1, 0 }, range = 8 } },
		{ name = "launcher", parent = "base", shape = "box", size = { 1.6, 0.3, 2.6 }, at = { 0, 1.65, -0.3 }, pivot = { 0, 1.5, -0.3 }, color = "dark" },
		{ name = "tube0", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 3.6 }, at = { -0.45, 2.05, -0.6 }, color = "metal" },
		{ name = "tube1", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 3.6 }, at = { 0.45, 2.05, -0.6 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { 0, 2.05, -2.5 } },
	},
}
