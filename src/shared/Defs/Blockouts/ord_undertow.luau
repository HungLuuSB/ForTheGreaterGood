--!strict
-- Undertow (Order torpedo launcher, T1, footprint 1): a floating armored
-- pad with a sonar dome below, a turntable (`turret`) and a three-tube
-- `launcher` house (the weapon turns it). Model space, forward = -Z.

return {
	id = "ord_undertow",
	parts = {
		{ name = "base", shape = "box", size = { 6, 1, 6 }, at = { 0, 0.2, 0 }, color = "hull" },
		{ name = "team", parent = "base", shape = "box", size = { 3, 0.08, 1 }, at = { 0, 0.74, 2.3 }, color = "team" },
		{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 2.4, 0.8, 2.4 }, at = { 0, 1.1, -0.6 }, color = "dark" },
		{ name = "sonar", parent = "base", shape = "cylinder", axis = "y", size = { 2, 0.6, 2 }, at = { 0, -0.4, 0 }, color = "glass" },
		{ name = "launcher", parent = "base", shape = "box", size = { 2.6, 1, 3 }, at = { 0, 1.9, -0.6 }, pivot = { 0, 1.4, -0.6 }, color = "hull" },
		{ name = "tube0", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 3.4 }, at = { -0.7, 1.9, -0.8 }, color = "metal" },
		{ name = "tube1", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 3.4 }, at = { 0, 1.9, -0.8 }, color = "metal" },
		{ name = "tube2", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 3.4 }, at = { 0.7, 1.9, -0.8 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { 0, 1.9, -2.6 } },
	},
}
