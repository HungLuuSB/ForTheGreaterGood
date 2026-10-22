--!strict
-- Hellmouth (Chaos self-propelled mortar): heavy hull with a recoil spade at
-- the back, an open casemate with a short, fat tube, a loader arm on one side
-- and ammo crates and a stack on the deck. Model space, forward = -Z
-- (docs/contracts/rig.md).

return {
	id = "chs_hellmouth",
	parts = {
		{ name = "base", shape = "box", size = { 5.8, 1.6, 7.2 }, at = { 0, 1.6, 0.2 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.4, 1.6, 7.8 }, at = { -3.0, 0.8, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.4, 1.6, 7.8 }, at = { 3.0, 0.8, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "skirtL", parent = "base", shape = "box", size = { 0.3, 1.1, 6.8 }, at = { -3.85, 1.5, 0.1 }, color = "dark" },
		{ name = "spade", parent = "base", shape = "box", size = { 5.0, 1.4, 0.35 }, at = { 0, 1.0, 4.2 }, rot = { 25, 0, 0 }, color = "dark" },
		{ name = "crate1", parent = "base", shape = "box", size = { 1.3, 0.8, 1.6 }, at = { 2.0, 2.8, 2.7 }, color = "metal" },
		{ name = "crate2", parent = "base", shape = "box", size = { 1.0, 0.6, 1.0 }, at = { 1.9, 3.5, 2.5 }, rot = { 0, 15, 0 }, color = "dark" },
		{ name = "stack", parent = "base", shape = "cylinder", axis = "y", size = { 0.6, 1.8, 0.6 }, at = { -2.2, 3.3, 3.0 }, color = "metal" },

		{ name = "turret", parent = "base", shape = "box", size = { 3.6, 1.4, 3.4 }, at = { 0, 3.1, 0 }, color = "team" },
		{ name = "pit", parent = "turret", shape = "box", size = { 2.2, 0.1, 2.0 }, at = { 0, 3.82, 0.4 }, color = "dark" },
		{ name = "loaderArm", parent = "turret", shape = "box", size = { 0.4, 0.4, 2.2 }, at = { 2.05, 3.5, 0.3 }, color = "metal" },
		{ name = "loaderJoint", parent = "turret", shape = "ball", size = { 0.7, 0.7, 0.7 }, at = { 2.05, 3.5, 1.4 }, color = "metal" },

		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 1.3, 1.3, 3.6 }, at = { 0, 3.3, -2.6 }, pivot = { 0, 3.3, -0.8 }, color = "metal" },
		{ name = "breech", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.7, 1.7, 0.6 }, at = { 0, 3.3, -1.3 }, color = "dark" },
		{ name = "lip", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.7, 1.7, 0.5 }, at = { 0, 3.3, -4.3 }, color = "dark" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 3.3, -4.6 } },
	},
}
