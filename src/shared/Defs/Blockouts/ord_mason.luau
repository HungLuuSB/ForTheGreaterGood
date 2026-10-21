--!strict
-- Mason (Order ground worker): Lancer-family tracked hull with a dozer blade
-- and a glass cab; at the back a turntable crane (nano) whose boom rises
-- forward to a blue emitter. Model space, forward = -Z
-- (docs/contracts/rig.md).

-- The boom is 4.2 long and tilted up 35° at the front: its front end is at
-- z = 0.7 - 2.1 cos 35° ≈ -1.02, y = 3.9 + 2.1 sin 35° ≈ 5.10.
return {
	id = "ord_mason",
	parts = {
		{ name = "base", shape = "box", size = { 5.0, 1.3, 6.6 }, at = { 0, 1.55, 0.4 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 5.0, 1.3, 1.2 }, at = { 0, 1.55, -3.5 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.1, 1.3, 7.8 }, at = { -2.65, 0.65, -0.1 }, color = "track" },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.1, 1.3, 7.8 }, at = { 2.65, 0.65, -0.1 }, color = "track" },
		{ name = "fenderL", parent = "base", shape = "box", size = { 1.3, 0.2, 7.4 }, at = { -2.65, 1.4, -0.1 }, color = "dark" },
		{ name = "fenderR", parent = "base", shape = "box", size = { 1.3, 0.2, 7.4 }, at = { 2.65, 1.4, -0.1 }, color = "dark" },
		{ name = "blade", parent = "base", shape = "box", size = { 6.0, 1.1, 0.3 }, at = { 0, 0.85, -4.6 }, rot = { -12, 0, 0 }, color = "metal" },
		{ name = "bladeArmL", parent = "base", shape = "box", size = { 0.3, 0.3, 1.0 }, at = { -1.8, 0.9, -4.1 }, color = "dark" },
		{ name = "bladeArmR", parent = "base", shape = "box", size = { 0.3, 0.3, 1.0 }, at = { 1.8, 0.9, -4.1 }, color = "dark" },
		{ name = "cab", parent = "base", shape = "box", size = { 3.0, 0.9, 1.4 }, at = { 0, 2.65, -1.7 }, color = "hull" },
		{ name = "windshield", parent = "base", shape = "wedge", size = { 3.0, 0.9, 0.7 }, at = { 0, 2.65, -2.75 }, color = "glass" },

		{ name = "nano", parent = "base", shape = "cylinder", axis = "y", size = { 2.4, 0.5, 2.4 }, at = { 0, 2.45, 2.0 }, color = "team" },
		{ name = "boom", parent = "nano", shape = "box", size = { 0.8, 0.8, 4.2 }, at = { 0, 3.9, 0.7 }, rot = { 35, 0, 0 }, color = "hull" },
		{ name = "emitter", parent = "nano", shape = "ball", size = { 1.1, 1.1, 1.1 }, at = { 0, 5.15, -1.25 }, color = "glass" },
		{ name = "counterweight", parent = "nano", shape = "box", size = { 1.8, 0.9, 0.9 }, at = { 0, 3.15, 2.9 }, color = "team" },
	},
}
