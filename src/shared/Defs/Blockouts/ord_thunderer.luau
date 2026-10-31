--!strict
-- Thunderer (Order huge lightning and EMP tank, T3): a wide double-tracked hull,
-- a big turret with two lightning coils and an EMP dish between them. Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "ord_thunderer",
	parts = {
		{ name = "base", shape = "box", size = { 6.2, 1.8, 14 }, at = { 0, 1.4, 0 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 6.2, 1.44, 2.52 }, at = { 0, 1.58, -8.26 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 2, 1.46, 14.56 }, at = { -4, 0.73, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "skirtL", parent = "base", shape = "box", size = { 0.25, 1.26, 12.6 }, at = { -5.12, 1.49, 0 }, color = "hull" },
		{ name = "trackR", parent = "base", shape = "box", size = { 2, 1.46, 14.56 }, at = { 4, 0.73, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "skirtR", parent = "base", shape = "box", size = { 0.25, 1.26, 12.6 }, at = { 5.12, 1.49, 0 }, color = "hull" },
		{ name = "turret", parent = "base", shape = "box", size = { 6.4, 1.8, 6.2 }, at = { 0, 3.2, 0.8 }, color = "team" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 6.4, 1.8, 1.6 }, at = { 0, 3.2, -3.1 }, color = "team" },
		{ name = "coil1", parent = "turret", shape = "cylinder", axis = "y", size = { 0.8, 3, 0.8 }, at = { -2, 5.6, 0.2 }, color = "metal" },
		{ name = "coil1Ring1", parent = "turret", shape = "cylinder", axis = "y", size = { 1.28, 0.15, 1.28 }, at = { -2, 5, 0.2 }, color = "glass" },
		{ name = "coil1Ring2", parent = "turret", shape = "cylinder", axis = "y", size = { 1.28, 0.15, 1.28 }, at = { -2, 5.75, 0.2 }, color = "glass" },
		{ name = "coil1Ring3", parent = "turret", shape = "cylinder", axis = "y", size = { 1.28, 0.15, 1.28 }, at = { -2, 6.5, 0.2 }, color = "glass" },
		{ name = "coil1Top", parent = "turret", shape = "ball", size = { 1.44, 1.44, 1.44 }, at = { -2, 7.58, 0.2 }, color = "glass" },
		{ name = "coil2", parent = "turret", shape = "cylinder", axis = "y", size = { 0.8, 3, 0.8 }, at = { 2, 5.6, 0.2 }, color = "metal" },
		{ name = "coil2Ring1", parent = "turret", shape = "cylinder", axis = "y", size = { 1.28, 0.15, 1.28 }, at = { 2, 5, 0.2 }, color = "glass" },
		{ name = "coil2Ring2", parent = "turret", shape = "cylinder", axis = "y", size = { 1.28, 0.15, 1.28 }, at = { 2, 5.75, 0.2 }, color = "glass" },
		{ name = "coil2Ring3", parent = "turret", shape = "cylinder", axis = "y", size = { 1.28, 0.15, 1.28 }, at = { 2, 6.5, 0.2 }, color = "glass" },
		{ name = "coil2Top", parent = "turret", shape = "ball", size = { 1.44, 1.44, 1.44 }, at = { 2, 7.58, 0.2 }, color = "glass" },
		{ name = "emp", parent = "turret", shape = "cylinder", axis = "y", size = { 2.4, 0.3, 2.4 }, at = { 0, 4.9, 2.2 }, rot = { -25, 0, 0 }, color = "glass" },
	},
	attachments = {
		{ name = "muzzle", parent = "turret", at = { -2, 7.6, 0.2 } },
		{ name = "muzzle2", parent = "turret", at = { 2, 7.6, 0.2 } },
		{ name = "emp", parent = "turret", at = { 0, 5.1, 2.2 } },
	},
}
